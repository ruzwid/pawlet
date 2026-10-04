# Pawlet interface

Pawlet is a quiet character collection with a small animation studio. The characters provide the playfulness; navigation and controls stay predictable.

Emil Kowalski’s design engineering guidance informed the restrained motion, direct feedback and interruptible interactions. The UI/UX skill search suggested native translucent chrome and clear hierarchy. Its web landing patterns and luxury fonts did not fit a Mac utility, so the interface uses native system text, rounded display headings and semantic SwiftUI controls.

The palette uses warm off-white surfaces, a muted green stage and a deep green accent. Dark mode maps each role separately rather than darkening a screenshot. The normal secondary text exceeds 4.5:1 against its surfaces in both themes. Selection has a border and accessibility state as well as color. SF Symbols carry consistent action meanings.

The library toolbar owns actions for the whole collection. Pet options own individual file actions. Search filters the collection without affecting desktop visibility. The selected pet owns one preview, which starts still; choosing an animation is an explicit request to loop it. All nine states are discoverable as chips and in the preview menu. Gaze is included only for supported v2 sheets.

Preview and desktop playback are independent. Each has its own pause and timing policy. Reduce Motion suppresses preview playback while preserving frame stepping. UI navigation, repeated selection and keyboard input have no decorative animation. Buttons provide immediate pressed feedback without layout changes. Hover greetings have a global default and optional stable-ID overrides.
