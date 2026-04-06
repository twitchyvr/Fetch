import SwiftUI

// MARK: - Onboarding View

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentStep = 0

    private let steps = OnboardingStep.allSteps

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $currentStep) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    OnboardingStepView(step: step)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            .frame(width: 520, height: 380)

            // MARK: - Navigation

            HStack {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation { currentStep -= 1 }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                // Step indicators
                HStack(spacing: Design.Spacing.sm) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.accentColor : Color.secondary.opacity(0.3))
                            .frame(width: 7, height: 7)
                            .scaleEffect(index == currentStep ? 1.2 : 1.0)
                            .animation(.spring(duration: 0.25), value: currentStep)
                    }
                }

                Spacer()

                if currentStep < steps.count - 1 {
                    Button("Next") {
                        withAnimation { currentStep += 1 }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Get Started") {
                        hasCompletedOnboarding = true
                        isPresented = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, Design.Spacing.xl)
            .padding(.bottom, Design.Spacing.xl)
        }
        .frame(width: 520, height: 440)
    }
}

// MARK: - Onboarding Step Model

private struct OnboardingStep {
    let title: String
    let description: String
    let icon: String
    let features: [FeatureItem]

    struct FeatureItem {
        let icon: String
        let text: String
    }

    static let allSteps: [OnboardingStep] = [
        OnboardingStep(
            title: "Welcome to Fetch",
            description: "A powerful, native macOS frontend for yt-dlp.\nDownload video and audio from 1,800+ sites\nwith a clean, intuitive interface.",
            icon: "arrow.down.circle.fill",
            features: []
        ),
        OnboardingStep(
            title: "Paste or Drop",
            description: "Getting started is simple. Paste a URL, drag-and-drop a link, or let Fetch detect URLs from your clipboard automatically.",
            icon: "doc.on.clipboard",
            features: [
                FeatureItem(icon: "link.badge.plus", text: "Paste any supported URL to start"),
                FeatureItem(icon: "arrow.down.doc", text: "Drag and drop links directly"),
                FeatureItem(icon: "eye", text: "Automatic clipboard URL detection"),
            ]
        ),
        OnboardingStep(
            title: "Choose Your Format",
            description: "Pick exactly the format you want, or let Fetch choose the best quality automatically.",
            icon: "slider.horizontal.3",
            features: [
                FeatureItem(icon: "film", text: "Browse all available video and audio formats"),
                FeatureItem(icon: "star", text: "Save presets for repeated workflows"),
                FeatureItem(icon: "gearshape.2", text: "Advanced options for fine-grained control"),
            ]
        ),
        OnboardingStep(
            title: "Power Features",
            description: "Go beyond basic downloads with tools built for power users.",
            icon: "bolt.fill",
            features: [
                FeatureItem(icon: "forward.end.alt", text: "SponsorBlock: skip sponsor segments automatically"),
                FeatureItem(icon: "captions.bubble", text: "Download subtitles for AI text analysis"),
                FeatureItem(icon: "square.and.arrow.down.on.square", text: "Batch downloads for playlists and channels"),
                FeatureItem(icon: "keyboard", text: "Cmd+N new download, Cmd+Shift+V paste & fetch"),
            ]
        ),
    ]
}

// MARK: - Step View

private struct OnboardingStepView: View {
    let step: OnboardingStep

    var body: some View {
        VStack(spacing: Design.Spacing.lg) {
            Spacer()

            Image(systemName: step.icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.accentColor)
                .symbolRenderingMode(.hierarchical)
                .accessibilityHidden(true)

            Text(step.title)
                .font(.title.bold())
                .multilineTextAlignment(.center)

            Text(step.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .frame(maxWidth: 380)

            if !step.features.isEmpty {
                VStack(alignment: .leading, spacing: Design.Spacing.md) {
                    ForEach(Array(step.features.enumerated()), id: \.offset) { _, feature in
                        HStack(spacing: Design.Spacing.md) {
                            Image(systemName: feature.icon)
                                .font(.body)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 20)
                                .accessibilityHidden(true)
                            Text(feature.text)
                                .font(.callout)
                        }
                    }
                }
                .padding(.top, Design.Spacing.sm)
            }

            Spacer()
        }
        .padding(.horizontal, Design.Spacing.xl)
    }
}
