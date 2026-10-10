# Contract: `.stratum/models.json`

Schema and rules: [data-model.md](../data-model.md), Model file. Errors and their messages:
[hook.md](hook.md), Output: deny.

## Examples

Valid:

```json
{
  "st-close": { "model": "haiku", "effort": "xhigh" },
  "st-validate": { "effort": "high" },
  "st-review": {}
}
```

Each of these blocks every Stratum agent start:

```text
not json                                  cannot be read
["st-close"]                              must be a JSON object
{"st-closee": {"model": "haiku"}}         unknown agent st-closee
{"st-close": "haiku"}                     entry not an object
{"st-close": {"modle": "haiku"}}          unknown key modle
{"st-close": {"model": "gpt"}}            unknown model gpt
{"st-close": {"effort": "huge"}}          unknown effort huge
```

## Template

`templates/models.json` holds exactly the 8 entries in
[data-model.md](../data-model.md), Model template. `st-init` copies it on "no" (D11, D12, D15, D16).
This repo's `.stratum/models.json` holds the same content (FR-012). Equality is checked by hand
(quickstart section 3). `tests/test_model_files.sh` only checks that the file passes the hook,
because `st-model` edits this file.

## Git

`.stratum/models.json` is in `.gitignore` (this repo, and every repo `st-init` sets up).
