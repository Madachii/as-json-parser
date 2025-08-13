# JSON Parser for Sven Co-op

AngelScript JSON lexer and parser with a clean `JsonValue` API.

## Loading

Add to your plugin's entry script:

```as
#include "JsonParser"
```

and inside of `default_plugins.txt`
```txt
"plugin"
{
    "name" "as-json-parser"
    "script" "as-json-parser/JsonParser"
}
```
---

## API

### Parsing

```as
JsonValue@ ParseJson(const string &in jsonStr)
```

### Read a config file

```as
string raw = ReadFile("settings.json");
JsonValue@ cfg = ParseJson(raw);

string name   = cfg.Get("player_name").AsString();
int    hp     = cfg.Get("defaults").Get("hp").AsInt();
float  speed  = cfg.Get("defaults").Get("speed").AsFloat();
bool   admin  = cfg.Get("admin").AsBool();
```

### Modify and save

```as
cfg.Get("defaults").Set("hp", 200);
cfg.Set("player_name", "Madachi");
cfg.Set("last_login", "2026-06-28");

string json = cfg.ToJson();
File@ f = g_FileSystem.OpenFile("scripts/plugins/myplugin/settings.json", OpenFile::WRITE);
if (f !is null && f.IsOpen())
{
    f.Write(json);
    f.Close();
}
```

Haven't properly tested it for performance or in a real scenario.
