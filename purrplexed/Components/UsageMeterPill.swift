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
	var onUpgradeTap: (() -> Void)? = nil
	
	private var remaining: Int { total - used }

	var body: some View {
		Button(action: {
			if remaining == 0 {
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
		if remaining == 0 {
			return "Upgrade"
		} else {
			return "\(used)/\(total)"
		}
	}
	
	private var iconName: String {
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
		if remaining == 0 {
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
		if remaining == 0 {
			return "No free analyses remaining. Used \(used) of \(total). Tap to upgrade."
		} else {
			return "Used \(used) of \(total) free analyses today. \(remaining) remaining."
		}
	}
}

#Preview {
	VStack(spacing: DS.Spacing.m) {
		UsageMeterPill(used: 0, total: 3)
		UsageMeterPill(used: 1, total: 3)
		UsageMeterPill(used: 2, total: 3)
		UsageMeterPill(used: 3, total: 3) { 
			print("Upgrade tapped")
		}
	}
	.padding()
}
