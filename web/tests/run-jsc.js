// Command-line entry: scripts/test-web.sh runs this with macOS's built-in JavaScriptCore.
import { run } from './harness.js';
import './logic.test.js';
import './content.test.js';

await run(line => print(line));
