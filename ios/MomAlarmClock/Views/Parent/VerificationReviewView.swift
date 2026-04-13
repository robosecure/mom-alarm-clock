import SwiftUI

/// Parent reviews a child's verification proof and takes action.
/// Part of the two-way confirmation protocol.
struct VerificationReviewView: View {
    @Environment(ParentViewModel.self) private var vm
    @Environment(\.dismiss) private var dismiss

    let session: MorningSession

    @State private var denyReason = ""
    @State private var showDenySheet = false
    @State private var showEscalateSheet = false
    @State private var escalateReason = ""
    @State private var actionReceipt: String?
    @State private var approveNote = ""
    @State private var showApproveNoteSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                statusHeader
                verificationProof
                sessionDetails
                if vm.canActOnSession(session) {
                    actionButtons
                    if let remaining = session.reviewWindowMinutesRemaining {
                        Text("Review window closes in \(remaining) min")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                if let childMessage = session.childMessage {
                    childMessageCard(childMessage)
                }
            }
            .padding()
        }
        .navigationTitle("Review Verification")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showDenySheet) { denySheet }
        .sheet(isPresented: $showEscalateSheet) { escalateSheet }
        .alert("Action Complete", isPresented: Binding(
            get: { actionReceipt != nil },
            set: { if !$0 { actionReceipt = nil; dismiss() } }
        )) {
            Button("OK") { actionReceipt = nil; dismiss() }
        } message: {
            Text(actionReceipt ?? "")
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: statusIcon)
                .font(.system(size: 48))
                .foregroundStyle(statusColor)

            Text(statusText)
                .font(.title2.bold())

            Text(session.alarmFiredAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var statusIcon: String {
        switch session.state {
        case .pendingParentReview: "hourglass.circle.fill"
        case .verified: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        default: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch session.state {
        case .pendingParentReview: .orange
        case .verified: .green
        case .failed: .red
        default: .gray
        }
    }

    private var statusText: String {
        switch session.state {
        case .pendingParentReview: "Awaiting Your Review"
        case .verified: "Approved"
        case .failed: "Denied / Escalated"
        default: session.state.rawValue.capitalized
        }
    }

    // MARK: - Verification Proof

    @ViewBuilder
    private var verificationProof: some View {
        if let result = session.verificationResult {
            VStack(alignment: .leading, spacing: 12) {
                Label("Verification Proof", systemImage: "checkmark.shield")
                    .font(.headline)

                proofRow(label: "Method", value: result.method.displayName, icon: result.method.systemImage)
                proofRow(label: "Tier", value: result.tier.displayName, icon: "gauge.medium")
                proofRow(label: "Completed", value: result.completedAt.formatted(date: .omitted, time: .standard), icon: "clock")
                proofRow(label: "Result", value: result.passed ? "Passed" : "Failed", icon: result.passed ? "checkmark" : "xmark")

                Divider()

                Text(result.proofSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        } else {
            Text("No verification data available.")
                .foregroundStyle(.secondary)
                .padding()
        }
    }

    private func proofRow(label: String, value: String, icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value)
                .font(.subheadline)
            Spacer()
        }
    }

    // MARK: - Session Details

    private var sessionDetails: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Session Details", systemImage: "info.circle")
                .font(.headline)

            if let duration = session.wakeUpDuration {
                HStack {
                    Text("Wake-up time:")
                    Spacer()
                    Text(Date.durationString(from: duration))
                        .foregroundStyle(session.wasOnTime ? .green : .orange)
                }
                .font(.subheadline)
            }

            if session.snoozeCount > 0 {
                HStack {
                    Text("Snoozes used:")
                    Spacer()
                    Text("\(session.snoozeCount)")
                        .foregroundStyle(.orange)
                }
                .font(.subheadline)
            }

            if session.tamperCount > 0 {
                HStack {
                    Text("Tamper events:")
                    Spacer()
                    Text("\(session.tamperCount)")
                        .foregroundStyle(.red)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if session.denialCount >= 2 {
                HStack(spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                    Text("Denied \(session.denialCount) times. Consider switching verification method or lowering difficulty for tomorrow.")
                        .font(.caption)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            }
            Button {
                Task {
                    if !approveNote.isEmpty {
                        await vm.sendMessage(approveNote, toSession: session.id)
                    }
                    await vm.approveSession(session.id)
                    let rewardNote = vm.lastRewardOutcome.map { " (+\($0.pointsDelta) points)" } ?? ""
                    actionReceipt = "Approved!\(rewardNote) Great job getting up."
                }
            } label: {
                Label("Approve", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.large)

            TextField("Add a note (optional)", text: $approveNote)
                .font(.subheadline)
                .textFieldStyle(.roundedBorder)

            Button {
                showDenySheet = true
            } label: {
                Label("Deny — Require Re-verification", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                showEscalateSheet = true
            } label: {
                Label("Escalate Consequences", systemImage: "exclamationmark.triangle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .controlSize(.large)
        }
    }

    private func childMessageCard(_ message: String) -> some View {
        HStack {
            Image(systemName: "message.fill")
                .foregroundStyle(.blue)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Sheets

    private var denySheet: some View {
        NavigationStack {
            Form {
                Section("Quick reasons") {
                    ForEach(["Not up yet", "Too slow", "Try again"], id: \.self) { template in
                        Button(template) {
                            denyReason = template
                        }
                        .foregroundStyle(denyReason == template ? .blue : .primary)
                    }
                }
                Section("Or write your own") {
                    TextField("Reason (optional)", text: $denyReason)
                }
                Section {
                    Button("Deny Verification") {
                        Task {
                            await vm.denySession(session.id, reason: denyReason)
                            showDenySheet = false
                            actionReceipt = "Denied. Child must re-verify." + (denyReason.isEmpty ? "" : " Reason: \(denyReason)")
                        }
                    }
                    .bold()
                }
            }
            .navigationTitle("Deny Verification")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDenySheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var escalateSheet: some View {
        NavigationStack {
            Form {
                Section("Why are you escalating?") {
                    TextField("Reason", text: $escalateReason)
                }
                Section {
                    Text("This will mark the session as failed and may affect the child's streak and reward points.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Section {
                    Button("Escalate", role: .destructive) {
                        Task {
                            await vm.escalateSession(session.id, reason: escalateReason)
                            showEscalateSheet = false
                            actionReceipt = "Escalated. Streak reset, -25 points, harder verification tomorrow."
                        }
                    }
                    .bold()
                }
            }
            .navigationTitle("Escalate Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showEscalateSheet = false }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
