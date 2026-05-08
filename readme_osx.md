## OSX Build of MSHV

This thing is ported and patched with AI tools. Please use the agent_instructions.md to seed your context.

Everything in this copy is experimental, use at your own risk...

The build will need to have some security stuff disabled. If you don't know what this is or what it does, best to not do this...

```bash
sudo xattr -r -d com.apple.quarantine MSHV-OSX.app
```
\<EOM\>

## Agent Release Notes

_Content below this line is auto generated.._

----
- `build-4` (2026-05-07): FT8 and multi-answer refresh with serialized variable decoder state, an option to disable Multi TX HF restrictions, and SM condensed replies in MA Standard. [Detailed release notes](https://github.com/jaisingh/MSHV/releases/tag/build-4)
- `build-3` (2026-05-05): FT8 decoder threading and FFTW plan stabilization, improved low-end macOS TX output scaling, and new POTA/SOTA macro activity presets. [Detailed release notes](https://github.com/jaisingh/MSHV/releases/tag/build-3)
- `build-2` (2026-05-05): first tagged macOS GitHub release build published from this fork. [Detailed release notes](https://github.com/jaisingh/MSHV/releases/tag/build-2)
- `build-1` (2026-05-05, pre-release): initial macOS app bundle published for early fork validation. [Detailed release notes](https://github.com/jaisingh/MSHV/releases/tag/build-1)
