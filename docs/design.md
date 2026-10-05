# Pawlet interface

Pawlet is a quiet character collection with a small animation studio. The characters provide the playfulness; navigation and controls stay predictable.

Emil Kowalski’s design engineering guidance informed the restrained motion, direct feedback and interruptible interactions. The UI/UX skill search suggested native translucent chrome and clear hierarchy. Its web landing patterns and luxury fonts did not fit a Mac utility, so the interface uses native system text, rounded display headings and semantic SwiftUI controls.

The palette uses warm paper surfaces, a muted olive stage and an olive accent. Dark mode maps each role separately rather than darkening a screenshot. The normal secondary text exceeds 4.5:1 against its surfaces in both themes. Selection has a border and accessibility state as well as color. SF Symbols carry consistent action meanings.

The library toolbar owns actions for the whole collection. Pet options own individual file actions. Search filters the collection without affecting desktop visibility. The selected pet owns one preview, which starts still; choosing an animation is an explicit request to loop it. All nine states are discoverable as chips and in the preview menu. Gaze is included only for supported v2 sheets.

Preview and desktop playback are independent. Each has its own pause and timing policy. Reduce Motion suppresses preview playback while preserving frame stepping. UI navigation, repeated selection and keyboard input have no decorative animation. Buttons provide immediate pressed feedback without layout changes. Hover greetings have a global default and optional stable-ID overrides.

The library uses a single “Your minis” heading with a quiet count. Navigation keeps visible labels in a compact sidebar, without section captions or repeated taglines. The paw is an original vector drawing with plump oval toes and a smooth rounded triangular pad. The application icon pairs a coral paw with warm cream; template versions follow the interface accent and macOS menu-bar appearance.

Light mode follows the supplied Granola reference with warm paper surfaces, charcoal text and olive accents. The sidebar uses a defined surface rather than a system material. Settings use the same semantic tokens as the library, with compact sections and no page title or subtitle. Switches use contrasting thumbs, separate off-state outlines and native Toggle accessibility representations; the whole row is clickable. Dark mode uses neutral charcoal surfaces and grey interaction fills, reserving olive for accents.

All app-owned rounded surfaces use `PawletTheme.roundedShape`, a SwiftUI continuous rounded rectangle. Backgrounds, clipping and borders share the same geometry. Fields and dropdown shells follow it too; native macOS windows, menus and alerts retain system chrome. Circular slider and switch thumbs stay circular.

Mini cards inset the artwork stage by eight points and round it independently, keeping the title and visibility action inside the outer card. Show and Hide use matching eye symbols; filled Hide versus outlined Show controls distinguish desktop visibility. Sidebar rows define their complete continuous rectangle as the click target.

App-owned controls use shared hover and press surfaces; mini-card selection highlights only its outer border. Pointer hover fades only a background tint over 100 ms with cubic-bezier (0.23, 1, 0.32, 1); press feedback and navigation are immediate. Reduce Motion keeps the tint and removes its fade. Input focus has a persistent accent outline independent of hover. Native NSMenu content is anchored to SwiftUI button triggers so macOS cannot strip their custom hit areas or styling. Menu action targets are retained through the menu lifetime, and the anchor is weakly referenced.

### Interaction states in 0.6.6

Mini-card hover and selection use the same outer accent border; the artwork and name surfaces remain unchanged. Visible minis have filled Hide controls, while hidden minis have outlined Show controls.

Secondary controls use neutral text and icons with a single 11% neutral overlay for hover, selection and press in both themes. Sidebar navigation opts into olive text and tints; primary buttons retain their filled olive treatment. Combined states do not add opacity. Primary controls keep their filled hierarchy with the same subtle overlay for hover and press. Dark mode uses neutral charcoal surfaces and neutral secondary-control text, with olive reserved for sidebar accents and filled primary controls. Mini cards show only the name and visibility action; visibility also remains available to accessibility clients.

Settings toggle rows keep a plain background on hover and press. The full row remains clickable, and the switch thumb and track communicate the state. Standalone buttons and dropdown triggers retain their hover feedback.
