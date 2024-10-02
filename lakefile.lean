import Lake
open Lake DSL

package «galeShapley» where
  -- Settings applied to both builds and interactive editing
  leanOptions := #[
    ⟨`pp.unicode.fun, true⟩ -- pretty-prints `fun a ↦ b`
  ]
  -- add any additional package configuration options here

  -- TODO: Swap to stable version of mathlib once a version for 4.12 is tagged
require mathlib from git
  "https://github.com/leanprover-community/mathlib4.git" -- @ s!"v{Lean.versionString}"

@[default_target]
lean_lib «GaleShapley» where
  -- add any library configuration options here

lean_exe «GaleShapleyCompute» where
  root := `GaleShapleyCompute
