# Contributing

Open an issue with the module, minimal reproduction, expected result, and Studio version.
For pet issues, include a small primitive reproduction of the model naming and joint layout.

Keep changes focused. From the repository root run:

```sh
luau scripts/money-tests.luau
luau scripts/utility-tests.luau
lune run scripts/roaming-tests.luau
lune run scripts/animator-tests.luau
stylua --check src tests scripts examples
rojo build default.project.json -o dist/GameplayToolkit.rbxmx
rojo build demo.project.json -o dist/GameplayToolkitDemo.rbxlx
```

Use Luau 0.743, Lune 0.10.5, StyLua 2.6.0, and Rojo 7.7.1 to match CI.
Compile all Luau files with `luau-compile --null`. Lune is a development-only test runtime;
it is not shipped in the toolkit. The portable roaming adapter and mocked lifecycle suite
do not verify Roblox physics, engine rendering, or streaming behavior.

Engine changes also need the Studio suites in the separate demo place. Update relevant API
documentation and add a regression case for a behavior bug. Commit the rebuilt dist artifacts;
CI rejects stale downloads. State missing engine validation explicitly in the pull request.

Do not include private game saves, account credentials, player records, purchased assets,
or third-party models without an appropriate redistribution license.

