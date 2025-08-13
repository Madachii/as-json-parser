#include "JsonLexer"

enum JsonType { JSON_NULL, JSON_BOOL, JSON_NUMBER, JSON_STRING, JSON_ARRAY, JSON_OBJECT }

string _EscapeJson(const string &in s)
{
    string r;
    for (uint i = 0; i < s.Length(); i++)
    {
        int c = s[i];
        if      (c == 34) r += "\\\"";   // '"'
        else if (c == 92) r += "\\\\";   // '\\'
        else if (c == 47) r += "\\/";    // '/'
        else if (c ==  8) r += "\\b";
        else if (c == 12) r += "\\f";
        else if (c == 10) r += "\\n";
        else if (c == 13) r += "\\r";
        else if (c ==  9) r += "\\t";
        else             r += s[i];
    }
    return r;
}

class JsonValue
{
    private JsonType jtype;
    private string sVal;
    private float  nVal;
    private bool   bVal;

    private dictionary        objVal;
    private array<JsonValue@> arrVal;

    JsonValue()                              { jtype = JSON_NULL; sVal = ""; nVal = 0.0; bVal = false; }
    JsonValue(JsonType t)                    { jtype = t;       sVal = ""; nVal = 0.0; bVal = false; }
    JsonValue(JsonType t, const string &in s){ jtype = t;       sVal = s; nVal = 0.0; bVal = false; }
    JsonValue(JsonType t, float n)           { jtype = t;       sVal = ""; nVal = n;  bVal = false; }
    JsonValue(JsonType t, bool b)            { jtype = t;       sVal = ""; nVal = 0.0; bVal = b;    }


    string Type()
    {
        switch (jtype)
        {
            case JSON_STRING: return "string";
            case JSON_NUMBER: return "number";
            case JSON_BOOL:   return "bool";
            case JSON_ARRAY:  return "array";
            case JSON_OBJECT: return "object";
            default:          return "null";
        }
    }

    bool IsObject() { return jtype == JSON_OBJECT; }
    bool IsArray()  { return jtype == JSON_ARRAY;  }
    bool IsString() { return jtype == JSON_STRING; }
    bool IsNumber() { return jtype == JSON_NUMBER; }
    bool IsBool()   { return jtype == JSON_BOOL;   }
    bool IsNull()   { return jtype == JSON_NULL;   }


    string AsString() { return jtype == JSON_STRING ? sVal           : "";      }
    int    AsInt()    { return jtype == JSON_NUMBER ? int(nVal)      : 0;       }
    float  AsFloat()  { return jtype == JSON_NUMBER ? nVal           : 0.0;     }
    bool   AsBool()   { return jtype == JSON_BOOL   ? bVal           : false;   }


    bool Has(const string &in key)
    {
        return jtype == JSON_OBJECT && objVal.exists(key);
    }

    array<string>@ Keys()
    {
        return jtype == JSON_OBJECT ? objVal.getKeys() : null;
    }

    JsonValue@ Get(const string &in key)
    {
        if (jtype != JSON_OBJECT) return null;
        JsonValue@ child;
        if (objVal.get(key, @child)) return child;
        return null;
    }


    void Set(const string &in key, JsonValue@ val)
    {
        _Ensure(JSON_OBJECT);
        @objVal[key] = val;
    }

    void Set(const string &in key, const string &in val)
    {
        Set(key, JsonValue(JSON_STRING, val));
    }

    void Set(const string &in key, float val)
    {
        Set(key, JsonValue(JSON_NUMBER, val));
    }

    void Set(const string &in key, int val)    { Set(key, float(val)); }
    void Set(const string &in key, bool val)
    {
        Set(key, JsonValue(JSON_BOOL, val));
    }

    void SetNull(const string &in key)         { Set(key, JsonValue(JSON_NULL)); }
    void Remove(const string &in key)          { if (jtype == JSON_OBJECT) objVal.delete(key); }


    uint Length()
    {
        return jtype == JSON_ARRAY ? arrVal.length() : 0;
    }

    JsonValue@ At(uint idx)
    {
        if (jtype != JSON_ARRAY || idx >= arrVal.length()) return null;
        return arrVal[idx];
    }


    void Push(JsonValue@ val)
    {
        _Ensure(JSON_ARRAY);
        arrVal.insertLast(val);
    }

    void Push(const string &in val)
    {
        Push(JsonValue(JSON_STRING, val));
    }

    void Push(float val)
    {
        Push(JsonValue(JSON_NUMBER, val));
    }

    void Push(int val)       { Push(float(val)); }
    void Push(bool val)
    {
        Push(JsonValue(JSON_BOOL, val));
    }

    void PushNull()          { Push(JsonValue(JSON_NULL)); }


    string ToJson()
    {
        switch (jtype)
        {
            case JSON_NULL:   return "null";
            case JSON_BOOL:   return bVal ? "true" : "false";
            case JSON_NUMBER: return "" + nVal;
            case JSON_STRING: return "\"" + _EscapeJson(sVal) + "\"";

            case JSON_ARRAY:
            {
                string s = "[";
                for (uint i = 0; i < arrVal.length(); i++)
                {
                    if (i > 0) s += ",";
                    s += arrVal[i].ToJson();
                }
                return s + "]";
            }

            case JSON_OBJECT:
            {
                string s = "{";
                array<string>@ keys = objVal.getKeys();
                for (uint i = 0; i < keys.length(); i++)
                {
                    if (i > 0) s += ",";
                    JsonValue@ child;
                    objVal.get(keys[i], @child);
                    s += "\"" + _EscapeJson(keys[i]) + "\":" + child.ToJson();
                }
                return s + "}";
            }
        }
        return "null";
    }

    private void _Ensure(JsonType t)
    {
        if (jtype == JSON_NULL)
            jtype = t;
    }
};


class JsonParser
{
    private Lexer lexer;
    private Token current;

    JsonParser() {}

    private string Consume(TokenType expected)
    {
        if (current.type != expected)
        {
            print("Parse error: Expected " + TokenTypeName(expected)
                + ", got " + TokenTypeName(current.type));
            return "";
        }

        string val = current.value;
        current = lexer.ReadNextToken();
        return val;
    }

    private JsonValue@ ParseValue()
    {
        switch (current.type)
        {
            case TokenType::LEFT_BRACE:
                return ParseObject();

            case TokenType::LEFT_BRACKET:
                return ParseArray();

            case TokenType::STRING:
            {
                return JsonValue(JSON_STRING, Consume(TokenType::STRING));
            }

            case TokenType::NUMBER:
            {
                return JsonValue(JSON_NUMBER, atof(Consume(TokenType::NUMBER)));
            }

            case TokenType::TRUE:
            {
                Consume(TokenType::TRUE);
                return JsonValue(JSON_BOOL, true);
            }

            case TokenType::FALSE:
            {
                Consume(TokenType::FALSE);
                return JsonValue(JSON_BOOL, false);
            }

            case TokenType::NULL:
            {
                Consume(TokenType::NULL);
                return JsonValue(JSON_NULL);
            }

            default:
                print("Parse error: Unexpected token "
                    + TokenTypeName(current.type));
                current = lexer.ReadNextToken();
                return JsonValue(JSON_NULL);
        }
    }

    private JsonValue@ ParseObject()
    {
        JsonValue@ obj = JsonValue(JSON_OBJECT);
        Consume(TokenType::LEFT_BRACE);

        if (current.type == TokenType::RIGHT_BRACE)
        {
            Consume(TokenType::RIGHT_BRACE);
            return obj;
        }

        while (true)
        {
            string key = Consume(TokenType::STRING);
            Consume(TokenType::COLON);
            obj.Set(key, ParseValue());

            if (current.type == TokenType::RIGHT_BRACE)
            {
                Consume(TokenType::RIGHT_BRACE);
                break;
            }

            Consume(TokenType::COMMA);
        }

        return obj;
    }

    private JsonValue@ ParseArray()
    {
        JsonValue@ arr = JsonValue(JSON_ARRAY);
        Consume(TokenType::LEFT_BRACKET);

        if (current.type == TokenType::RIGHT_BRACKET)
        {
            Consume(TokenType::RIGHT_BRACKET);
            return arr;
        }

        while (true)
        {
            arr.Push(ParseValue());

            if (current.type == TokenType::RIGHT_BRACKET)
            {
                Consume(TokenType::RIGHT_BRACKET);
                break;
            }

            Consume(TokenType::COMMA);
        }

        return arr;
    }

    JsonValue@ Parse(const string &in jsonStr)
    {
        lexer.Reset(jsonStr);
        current = lexer.ReadNextToken();

        if (current.type == TokenType::END_OF_FILE)
        {
            print("Parse error: Empty input");
            return JsonValue(JSON_NULL);
        }

        JsonValue@ result = ParseValue();

        if (current.type != TokenType::END_OF_FILE)
            print("Parse warning: Trailing tokens");

        return result;
    }
}

JsonValue@ ParseJson(const string &in jsonStr)
{
    JsonParser parser;
    return parser.Parse(jsonStr);
}
