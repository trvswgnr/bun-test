# @travvy/bun-test

[![npm version](https://img.shields.io/npm/v/@travvy/bun-test.svg)](https://www.npmjs.com/package/@travvy/bun-test)

Type definitions for Bun's test runner without requiring the full `@types/bun` package.

## Description

This package re-exports the TypeScript type definitions for `bun:test` so that you can use Bun as a test runner without needing to install the complete `@types/bun` package as a dependency.

This is particularly useful for:

- Libraries that use Bun only for testing but don't depend on Bun at runtime
- Projects that want to minimize their dependency footprint
- Codebases that need type definitions only for Bun's test runner

## Installation

Install the package with an alias so TypeScript can find it automatically:

```bash
# bun
bun i -d @types/bun-test@npm:@travvy/bun-test

# npm
npm i -D @types/bun-test@npm:@travvy/bun-test
```

This installs the package `@travvy/bun-test` but aliases it as `@types/bun-test` so TypeScript automatically picks up the type definitions (packages from `@types/*` are special).

## Usage

Once installed with the proper alias, TypeScript will automatically pick up the type definitions for `bun:test`. You can import and use the test runner as normal:

```typescript
import { test, expect, describe } from "bun:test";

test("my test", () => {
  expect(1 + 1).toBe(2);
});

describe("group", () => {
  test("nested test", () => {
    expect(true).toBeTrue();
  });
});
```

## Why use this instead of @types/bun?

- **Smaller dependency footprint**: Only includes the types needed for testing
- **Focused purpose**: When you only need Bun as a test runner
- **Cleaner dependency graph**: Avoid depending on the full Bun typings when unnecessary

## License

MIT

## Links

- [GitHub Repository](https://github.com/trvswgnr/bun-test)
- [npm Package](https://www.npmjs.com/package/@travvy/bun-test)
- [Bun Documentation](https://bun.sh/docs/cli/test)

