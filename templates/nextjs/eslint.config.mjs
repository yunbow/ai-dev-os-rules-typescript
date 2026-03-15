import { defineConfig, globalIgnores } from "eslint/config";
import nextVitals from "eslint-config-next/core-web-vitals";
import nextTs from "eslint-config-next/typescript";

const eslintConfig = defineConfig([
  ...nextVitals,
  ...nextTs,
  globalIgnores([
    ".next/**",
    "out/**",
    "build/**",
    "next-env.d.ts",
    "node_modules/**",
  ]),
  {
    rules: {
      // console.log 警告（console.error と warn は許可）
      // ガイドライン: common/code.md - 本番コードに console.log を残さない
      "no-console": ["warn", { allow: ["error", "warn"] }],

      // 未使用変数の警告（_ で始まる変数は除外）
      "@typescript-eslint/no-unused-vars": [
        "warn",
        {
          argsIgnorePattern: "^_",
          varsIgnorePattern: "^_",
        },
      ],

      // any 型の使用をエラー
      // ガイドライン: common/code.md - any 禁止、unknown を使用
      "@typescript-eslint/no-explicit-any": "error",
    },
  },
]);

export default eslintConfig;
