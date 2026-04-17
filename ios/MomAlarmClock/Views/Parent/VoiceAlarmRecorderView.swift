import SwiftUI
import AVFoundation
import FirebaseStorage
import FirebaseCore

/// Guardian records a voice alarm clip (up to 30 seconds) for a child.
struct VoiceAlarmRecorderView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    @State private var recorder: AVAudioRecorder?
    @State private var player: AVAudioPlayer?
    @State private var isRecording = false
    @State private var isPlaying = false
    @State private var hasRecording = false
    @State private var recordingDuration: TimeInterval = 0
    @State private var timer: Timer?
    @State private var isUploading = false
    @State private var error: String?
    @State private var micPermissionGranted = false

    private let maxDuration: TimeInterval = 30
    private var tempFileURL: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("voiceAlarm_recording.m4a")
    }

    var body: some View {
        Form {
            Section {
                if !micPermissionGranted {
                    micPermissionView
                } else {
                    recordingControls
                }
            } header: {
                Text("Record a Message")
            } footer: {
                Text("Record up to 30 seconds. This will play when your child's alarm fires.")
            }

            if let existingAlarm = vm.selectedChild?.voiceAlarm, existingAlarm.enabled {
                Section("Current Voice Alarm") {
                    Label("Active", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text("Last updated: \(existingAlarm.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Remove Voice Alarm", role: .destructive) {
                        Task { await removeVoiceAlarm() }
                    }
                }
            }

            if let error {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Voice Alarm")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { checkMicPermission() }
        .onDisappear { stopRecording(); stopPlayback() }
    }

    // MARK: - Mic Permission

    private var micPermissionView: some View {
        VStack(spacing: 12) {
            Image(systemName: "mic.slash")
                .font(.title)
                .foregroundStyle(.orange)
            Text("Microphone access is required to record a voice alarm.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
            Button("Allow Microphone") {
                Task {
                    if await AVAudioApplication.requestRecordPermission() {
                        micPermissionGranted = true
                    }
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        VStack(spacing: 16) {
            // Duration indicator
            Text(String(format: "%02d:%02d", Int(recordingDuration) / 60, Int(recordingDuration) % 60))
                .font(.system(size: 48, design: .monospaced))
                .foregroundStyle(isRecording ? .red : .primary)

            // Progress bar
            if isRecording {
                ProgressView(value: recordingDuration, total: maxDuration)
                    .tint(.red)
            }

            HStack(spacing: 24) {
                // Record / Stop
                Button {
                    if isRecording { stopRecording() } else { startRecording() }
                } label: {
                    Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(isRecording ? .red : .blue)
                }

                // Play preview
                if hasRecording && !isRecording {
                    Button {
                        if isPlaying { stopPlayback() } else { playPreview() }
                    } label: {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                    }
                }
            }

            // Save button
            if hasRecording && !isRecording {
                Button {
                    Task { await uploadAndSave() }
                } label: {
                    if isUploading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else {
                        Label("Save Voice Alarm", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(isUploading)
            }
        }
        .padding(.vertical)
    }

    // MARK: - Recording

    private func checkMicPermission() {
        micPermissionGranted = AVAudioApplication.shared.recordPermission == .granted
    }

    private func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
        } catch {
            self.error = "Audio session error: \(error.localizedDescription)"
            return
        }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        do {
            recorder = try AVAudioRecorder(url: tempFileURL, settings: settings)
            recorder?.record(forDuration: maxDuration)
            isRecording = true
            recordingDuration = 0

            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                // Timer fires on main runloop; assumeIsolated satisfies Swift 6 strict concurrency.
                MainActor.assumeIsolated {
                    if let recorder, recorder.isRecording {
                        recordingDuration = recorder.currentTime
                    } else {
                        stopRecording()
                    }
                }
            }
        } catch {
            self.error = "Recording error: \(error.localizedDescription)"
        }
    }

    private func stopRecording() {
        timer?.invalidate()
        timer = nil
        if recorder?.isRecording == true {
            recorder?.stop()
        }
        isRecording = false
        hasRecording = FileManager.default.fileExists(atPath: tempFileURL.path)
    }

    // MARK: - Playback

    private func playPreview() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            player = try AVAudioPlayer(contentsOf: tempFileURL)
            player?.play()
            isPlaying = true
            // Auto-stop when done
            DispatchQueue.main.asyncAfter(deadline: .now() + (player?.duration ?? 0) + 0.5) {
                stopPlayback()
            }
        } catch {
            self.error = "Playback error: \(error.localizedDescription)"
        }
    }

    private func stopPlayback() {
        player?.stop()
        isPlaying = false
    }

    // MARK: - Upload

    private func uploadAndSave() async {
        guard let child = vm.selectedChild, let familyID = vm.familyID else {
            error = "No child selected"
            return
        }
        guard FirebaseApp.app() != nil else {
            error = "Firebase not configured"
            return
        }

        isUploading = true
        defer { isUploading = false }

        let storagePath = "families/\(familyID)/children/\(child.id.uuidString)/voiceAlarm/default.m4a"
        let storageRef = Storage.storage().reference(withPath: storagePath)

        do {
            let data = try Data(contentsOf: tempFileURL)
            let metadata = StorageMetadata()
            metadata.contentType = "audio/m4a"
            _ = try await storageRef.putDataAsync(data, metadata: metadata)

            // Update child profile with voice alarm metadata
            let voiceAlarm = ChildProfile.VoiceAlarmMetadata(
                enabled: true,
                storagePath: storagePath,
                updatedAt: Date(),
                fileSize: data.count
            )
            await vm.setVoiceAlarm(voiceAlarm)

            // Clean up temp file
            try? FileManager.default.removeItem(at: tempFileURL)
            dismiss()
        } catch {
            self.error = "Upload failed: \(error.localizedDescription)"
        }
    }

    private func removeVoiceAlarm() async {
        await vm.setVoiceAlarm(nil)
        // Optionally delete from Storage (not required — overwrite on next upload)
        dismiss()
    }
}
