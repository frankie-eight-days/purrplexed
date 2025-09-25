//
//  UsageMeterPill.swift
//  Purrplexed
//
//  Small pill showing remaining free count.
//

import SwiftUI

struct UsageMeterPill: View {
	let used: Int
	let total: Int
	let isPremium: Bool
	var onUpgradeTap: (() -> Void)? = nil
	
	private var remaining: Int { max(total - used, 0) }
	private var canUpgrade: Bool { !isPremium && remaining == 0 }

	var body: some View {
		Button(action: {
			if canUpgrade {
				onUpgradeTap?()
			}
		}) {
			HStack(spacing: DS.Spacing.s) {
				icon
				text
			}
			.font(.caption)
			.fontWeight(.semibold)
			.padding(.horizontal, DS.Spacing.s)
			.padding(.vertical, 6)
			.background(backgroundStyle)
			.clipShape(Capsule())
		}
		.buttonStyle(PlainButtonStyle())
		.accessibilityLabel(accessibilityText)
	}
	
	private var icon: some View {
		Image(systemName: iconName)
			.foregroundStyle(iconColor)
			.font(.system(size: 14, weight: .medium))
	}
	
	private var text: some View {
		Text(displayText)
			.foregroundStyle(textColor)
			.lineLimit(1)
	}
	
	private var displayText: String {
		if isPremium {
			return "∞ Unlimited"
		} else if canUpgrade {
			return "Upgrade"
		} else {
			return "\(used)/\(total)"
		}
	}
	
	private var iconName: String {
		if isPremium {
			return "infinity.circle.fill"
		}
		switch remaining {
		case 0:
			return "star.fill"
		case 1:
			return "exclamationmark.triangle.fill"
		case 2:
			return "clock.fill"
		default:
			return "checkmark.circle.fill"
		}
	}
	
	private var iconColor: Color {
		if isPremium {
			return .white
		}
		switch used {
		case 0:
			return .green
		case 1:
			return .yellow
		case 2:
			return .orange
		default:
			return .red
		}
	}
	
	private var textColor: Color {
		if isPremium {
			return .white
		}
		switch remaining {
		case 0:
			return .white
		case 1:
			return .primary
		case 2:
			return .primary
		default:
			return .primary
		}
	}
	
	private var backgroundStyle: some ShapeStyle {
		if isPremium {
			return AnyShapeStyle(LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing))
		} else if remaining == 0 {
			return AnyShapeStyle(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
		} else {
			switch used {
			case 0:
				return AnyShapeStyle(.green.opacity(0.2))
			case 1:
				return AnyShapeStyle(.yellow.opacity(0.2))
			case 2:
				return AnyShapeStyle(.orange.opacity(0.2))
			default:
				return AnyShapeStyle(.red.opacity(0.2))
			}
		}
	}
	
	private var accessibilityText: String {
		if isPremium {
			return "Premium active. Unlimited analyses available."
		} else if canUpgrade {
			return "No free analyses remaining. Used \(used) of \(total). Tap to upgrade."
		} else {
			return "Used \(used) of \(total) free analyses today. \(remaining) remaining."
		}
	}
}

#Preview {
	VStack(spacing: DS.Spacing.m) {
		UsageMeterPill(used: 0, total: 3, isPremium: false)
		UsageMeterPill(used: 1, total: 3, isPremium: false)
		UsageMeterPill(used: 2, total: 3, isPremium: false)
		UsageMeterPill(used: 3, total: 3, isPremium: false) {
			print("Upgrade tapped")
		}
		UsageMeterPill(used: 0, total: 3, isPremium: true)
	}
	.padding()
}
