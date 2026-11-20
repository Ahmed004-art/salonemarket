# SaloneMarket Motion Language

## Principles
- **Purpose‑driven:** every animation conveys meaning (state change, feedback).
- **Subtle:** reinforce UI changes without distracting the user.
- **Performance‑conscious:** avoid heavy compositing, no BackdropFilter.
- **Reduced‑motion:** respects `MediaQuery.disableAnimations`; provide instant fallbacks.

## Animation Table
| Name | Trigger | Duration | Easing | What changes | Implementation notes |
|---|---|---|---|---|---|
| Page Forward Transition | Navigation push | 300 ms | `cubic-bezier(0.2,0,0,1)` | Slide in from right 24 px + fade | Use `SharedAxisTransition` (horizontal) |
| Modal / Bottom Sheet | Overlay show | 280 ms | Decelerate | Slide up from bottom | `showModalBottomSheet` with custom `animationController` |
| Product Hero | List → Detail | 350 ms | Spring (damping 0.8) | Image expands in place | Wrap image in `Hero(tag: productId)` |
| Add‑to‑Cart Pulse | Add button tap | 200 ms (spring) | Spring | Cart badge scales 1→1.3→1 |
| Cart Icon Jiggle | Item added | 250 ms | Elastic | Icon rotates ±3° twice |
| Bottom Nav Indicator | Tab change | 220 ms | Ease | Indicator line slides & colour change |
| Checkout Step Fill | Step complete | 400 ms | Linear | Progress indicator fill |
| Payment Processing | Submit payment | Indefinite (loop) | Linear | Pulsing amber circle (800 ms cycle) |
| Payment Success | Payment succeeded | 600 ms | Ease‑out | Checkmark draw + scale expand |
| Payment Failure | Payment failed | 400 ms | Ease‑in‑out | Horizontal shake ±8 px × 3 |
| Skeleton Shimmer | Content loading | 1200 ms | Linear (infinite) | Shimmer sweep L→R |
| Product Card Press | Tap down/up | 100 ms / 150 ms | Ease | Scale 1→0.97→1 |

## Reduced‑motion Overrides (when `MediaQuery.disableAnimations` is true)
- Skip all transitions (instant navigation).
- Replace skeleton shimmer with static grey block.
- Omit hero animations.
- Keep payment success/failure feedback (checkmark or shake) but render instantly.

## Low‑End Device Guidance
- Detect via `deviceInfo.memory < 2 GB` or initial frame > 16 ms.
- In *performance mode*: disable hero transitions, use static placeholders instead of shimmer, skip non‑essential animations.
- Never use `BackdropFilter` or heavy blur effects on any screen.

## Implementation Tips (Flutter)
```dart
// Example: shared axis transition wrapper
class ForwardTransition extends StatelessWidget {
  final Widget child;
  const ForwardTransition({required this.child});
  @override
  Widget build(BuildContext context) {
    return PageTransitionSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, animation, secondaryAnimation) {
        return SharedAxisTransition(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          transitionType: SharedAxisTransitionType.horizontal,
          child: child,
        );
      },
      child: child,
    );
  }
}
```

---

**Design decisions awaiting sign‑off**
- Ensure the amber badge colour for simulated payment is never confused with the green real‑payment confirmation badge.