# FeedCI

Fail the build when a deploy breaks your RSS, Atom or JSON feed.

Check a built feed file before you ship, or a live URL after. Each run adds a summary to the job and links to a full report on [feeds.one](https://feeds.one/tools/feedci).

## Quick start

1. [Create a feeds.one API key](https://feeds.one/api-keys) that can run feed checks.
2. Save it as a repository secret named `FEEDS_ONE_API_KEY`.
3. Add a step to your workflow:

```yaml
- uses: feeds-one/feedci-action@v1
  with:
    api-key: ${{ secrets.FEEDS_ONE_API_KEY }}
    file: public/feed.xml
```

By default, any failed check fails the build.

## Examples

### Check a built file before deploying

```yaml
- uses: feeds-one/feedci-action@v1
  with:
    api-key: ${{ secrets.FEEDS_ONE_API_KEY }}
    file: public/feed.xml
    fail-on: warn
    require: item-ids,dates,full-text
    min-items: 1
```

### Check the live feed after deploying

```yaml
- uses: feeds-one/feedci-action@v1
  with:
    api-key: ${{ secrets.FEEDS_ONE_API_KEY }}
    url: https://example.com/feed.xml
    stable-ids: true
    max-age-days: 30
```

### Catch changed item IDs in a built file

A file has no address, so give it a `baseline` name to compare against. The first check sets the baseline.

```yaml
- uses: feeds-one/feedci-action@v1
  with:
    api-key: ${{ secrets.FEEDS_ONE_API_KEY }}
    file: public/feed.xml
    stable-ids: true
    baseline: main-feed
```

### Use the result in a later step

```yaml
- id: feedci
  uses: feeds-one/feedci-action@v1
  with:
    api-key: ${{ secrets.FEEDS_ONE_API_KEY }}
    url: https://example.com/feed.xml

- if: always()
  run: echo "${{ steps.feedci.outputs.outcome }} ${{ steps.feedci.outputs.report-url }}"
```

## Inputs

Set either `url` or `file`, not both.

| Input | Required | Default | Description |
|---|---|---|---|
| `api-key` | Yes | | A feeds.one API key. Store it as a repository secret. |
| `url` | One of `url` or `file` | | A live feed URL to check. |
| `file` | One of `url` or `file` | | Path to a built feed file, up to about 5 MB. |
| `fail-on` | No | `fail` | `fail` fails on failed checks only. `warn` also fails on anything marked as needing attention. |
| `require` | No | | Comma-separated checks that must pass, such as `item-ids,dates`. |
| `min-items` | No | | The fewest items the feed may contain. |
| `stable-ids` | No | | Set to `true` to fail if an existing item's ID changed since the last check. |
| `max-age-days` | No | | Fail if the newest item is older than this many days. |
| `require-licence` | No | | Set to `true` to fail if the feed declares no rights or licence information. |
| `baseline` | No | | A name to compare item IDs under. Needed for `stable-ids` when you check a file. |
| `allow-inconclusive` | No | `false` | Set to `true` to pass the build when a required check could not run. |
| `api-url` | No | `https://feeds.one/api/v1/feed-checks` | The feeds.one API endpoint. |

## Outputs

| Output | Description |
|---|---|
| `outcome` | `passed`, `failed` or `inconclusive`. |
| `report-url` | Link to the full report. |

Outputs are empty if the check could not run, for example when the API key is wrong.

## Checks

These names work with `require`:

| Target | Checks |
|---|---|
| Built file or live URL | `format`, `standards`, `quality`, `item-ids`, `dates`, `full-text` |
| Live URL only | `fetch`, `https`, `redirects`, `content-type`, `size`, `polling`, `discovery` |

To make sure a feed has items, use `min-items`.

If a required check can't run, the result is inconclusive and the build fails unless you set `allow-inconclusive: true`. FeedCI never counts an expectation it couldn't observe as met.

## Run it from the command line

Clone this repository and run `feedci`. It needs `bash`, `curl` and `jq`.

```sh
export FEEDCI_API_KEY=your-key
./feedci --file public/feed.xml --fail-on warn --min-items 1
./feedci --url https://example.com/feed.xml --stable-ids
./feedci --help
```

| Exit code | Meaning |
|---|---|
| `0` | Passed |
| `1` | Failed |
| `2` | Inconclusive |
| `3` | The check could not run |

## Good to know

- A live URL must be publicly reachable, because feeds.one fetches it.
- For a built file, feeds.one keeps the check results but not the file.
- Each run uses one feed check from your plan's monthly allowance. Free accounts include 500 a month.
- Self-hosted runners need `bash`, `curl` and `jq`.

## Licence

[MIT](LICENSE)
