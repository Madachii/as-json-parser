void print(const string &in text) { g_Game.AlertMessage(at_console, text); }

enum TokenType {
    LEFT_BRACE, RIGHT_BRACE, LEFT_BRACKET, RIGHT_BRACKET,
    TRUE, FALSE, NULL, COLON, COMMA,
    STRING, NUMBER, ERROR, END_OF_FILE
}

class Token
{
    TokenType type;
    string value;
    Token() { type = TokenType::ERROR; value = ""; }
    Token(TokenType t, const string &in v) { type = t; value = v; }
    Token(const Token &in other) { type = other.type; value = other.value; }
    Token &opAssign(const Token &inout other) { type = other.type; value = other.value; return this; }
}

class Lexer
{
    private string json;
    private uint jsonLen;
    private uint pos;

    Lexer() { json = ""; jsonLen = 0; pos = 0; }

    Lexer(const string &in jsonStr)
    {
        json = jsonStr;
        jsonLen = json.Length();
        pos = 0;
    }

    void Reset(const string &in jsonStr)
    {
        json = jsonStr;
        jsonLen = json.Length();
        pos = 0;
    }

    int Peek()
    {
        if (pos >= jsonLen)
            return -1;

        return json[pos];
    }

    int ReadChar()
    {
        int c = Peek();
        if (c != -1) pos++;

        return c;
    }

    bool IsEOF() { return pos >= jsonLen; }

    bool IsWhitespace()
    {
        int c = Peek();
        return c == 32 || c == 10 || c == 13 || c == 9;
        //         ' '        '\n'       '\r'       '\t'
    }

    string LastRead()
    {
        return json[pos - 1];
    }

    string ReadDigits()
    {
        string s;
        while (true)
        {
            int c = Peek();
            if (c >= 48 && c <= 57)   // '0'..'9'
            {
                ReadChar();
                s += LastRead();
            }
            else break;
        }
        return s;
    }

    Token Error(const string &in msg)
    {
        print("Lexer error: " + msg);
        return Token(TokenType::ERROR, msg);
    }

    int HexVal(int c)
    {
        if (c >= 48 && c <= 57)  return c - 48;   // '0'..'9'
        if (c >= 65 && c <= 70)  return c - 65 + 10;   // 'A'..'F'
        if (c >= 97 && c <= 102) return c - 97 + 10;   // 'a'..'f'
        return -1;
    }

    bool ExpectWord(const string &in word)
    {
        uint wlen = word.Length();
        if (pos + wlen > jsonLen)
            return false;

        if (json.SubString(pos, wlen) != word)
            return false;

        pos += wlen;
        return true;
    }


    string ReadEscapedSequence()
    {
        int c = ReadChar();
        if (c == -1)  return "";
        if (c == 34)  return "\"";        // '"'
        if (c == 92)  return "\\";         // '\\'
        if (c == 47)  return "/";            // '/'
        if (c == 98)  return "\x08";         // 'b' -> backspace
        if (c == 102) return "\x0C";         // 'f' -> form feed
        if (c == 110) return "\n";           // 'n'
        if (c == 114) return "\r";           // 'r'
        if (c == 116) return "\t";           // 't'
        // As of now, this is not going to handle high-surrogate unicode characters.
        if (c == 117)                          // 'u' -> unicode
        {
            string hex;
            for (uint i = 0; i < 4; i++)
            {
                if (pos >= jsonLen)
                {
                    print("Lexer error: Incomplete unicode escape");
                    return "";
                }

                int v = HexVal(json[pos]);
                if (v == -1)
                {
                    print("Lexer error: Invalid hex in \\u escape");
                    pos += 4 - i;
                    return "";
                }
                hex += json[pos];
                pos++;
            }
            return "\\u" + hex;
        }

        print("Lexer error: Invalid escape sequence");
        return "";
    }

    string ReadString()
    {
        string buf;
        while (pos < jsonLen)
        {
            int c = ReadChar();
            if (c == -1)
                break;

            if (c >= 0   && c <= 0x1f         // control chars
                || c >= 0x80 && c <= 0x9f      // extended control
                || c == 0x7f)                   // DEL
            {
                print("Lexer error: Unescaped control char");
                return buf;
            }

            if (c == 34)    // '"'
                return buf;

            if (c == 92)    // '\\'
            {
                buf += ReadEscapedSequence();
            }
            else
            {
                buf += json[pos - 1];
            }
        }

        print("Lexer error: Unterminated string literal");
        return buf;
    }

    int ReadDigit()
    {
        int c = ReadChar();
        if (c == -1)
        {
            print("Lexer error: Unexpected EOF, expected digit");
            return -1;
        }
        if (c < 48 || c > 57)    // '0'..'9'
        {
            print("Lexer error: Bad digit");
            return -1;
        }
        return c;
    }

    string ReadNumberFraction()
    {
        string buf;
        if (Peek() != 46)        // '.'
            return buf;

        ReadChar();
        buf += LastRead();      // add the dot

        int d = ReadDigit();    // make sure atleast one digit exists after dot
        if (d == -1)
            return buf;

        buf += LastRead();
        buf += ReadDigits();    // read the rest.

        return buf;
    }

    string ReadNumberExponent()
    {
        string buf;
        int c = Peek();
        if (c != 69 && c != 101) // 'E', 'e'
            return buf;

        ReadChar();
        buf += LastRead();
        c = Peek();
        if (c == 45 || c == 43)   // '-', '+'
        {
            ReadChar();
            buf += LastRead();
        }

        int d = ReadDigit();
        if (d == -1)
            return buf;

        buf += LastRead();
        buf += ReadDigits();
        return buf;
    }

    // known bug: leading zero's will result in a simple 0, aka 009 is 'valid' even tho it should throw a error.
    string ReadNumber()
    {
        int first = ReadChar();
        if (first == -1)
            return "";

        string buf;
        buf += LastRead();

        if (first == 48)        // '0'
        {
            buf += ReadNumberFraction();
            buf += ReadNumberExponent();
            return buf;
        }

        if (first == 45)        // '-'
        {
            int next = Peek();
            if (next == -1)
            {
                print("Lexer error: Expected digit after '-', got EOF");
                return buf;
            }

            if (next < 48 || next > 57)   // '0'..'9'
            {
                print("Lexer error: Expected digit after '-'");
                return buf;
            }

            ReadChar();
            buf += LastRead();
            if (next == 48)               // '0'
            {
                buf += ReadNumberFraction();
                buf += ReadNumberExponent();
                return buf;
            }
        }

        buf += ReadDigits();
        buf += ReadNumberFraction();
        buf += ReadNumberExponent();
        return buf;
    }


    Token ReadNextToken()
    {
        while (IsWhitespace()) ReadChar();

        if (IsEOF())
            return Token(TokenType::END_OF_FILE, "");

        int c = Peek();

        if (c == 116)           // 't'
        {
            if (ExpectWord("true"))  return Token(TokenType::TRUE,  "true");
            ReadChar();
            return Error("Expected 'true'");
        }
        if (c == 102)          // 'f'
        {
            if (ExpectWord("false")) return Token(TokenType::FALSE, "false");
            ReadChar();
            return Error("Expected 'false'");
        }
        if (c == 110)          // 'n'
        {
            if (ExpectWord("null"))  return Token(TokenType::NULL,  "null");
            ReadChar();
            return Error("Expected 'null'");
        }

        if (c == 45 || (c >= 48 && c <= 57))   // '-', '0'..'9'
            return Token(TokenType::NUMBER, ReadNumber());

        c = ReadChar();
        switch (c)
        {
            case 34: {
                string result = ReadString();
                return Token(TokenType::STRING, result);  // '"'
            }

            case 123: return Token(TokenType::LEFT_BRACE,    "{");   // '{'
            case 125: return Token(TokenType::RIGHT_BRACE,   "}");   // '}'
            case 91:  return Token(TokenType::LEFT_BRACKET,  "[");   // '['
            case 93:  return Token(TokenType::RIGHT_BRACKET, "]");   // ']'
            case 44:  return Token(TokenType::COMMA,         ",");   // ','
            case 58:  return Token(TokenType::COLON,         ":");   // ':'

            default:  return Error("Unexpected character: " + string(c));
        }
    }
}

array<Token>@ LexJson(const string &in jsonStr)
{
    Lexer lexer(jsonStr);
    array<Token> tokens;
    while (true)
    {
        Token tok = lexer.ReadNextToken();
        if (tok.type == TokenType::END_OF_FILE)
            break;
        tokens.insertLast(tok);
    }
    return @tokens;
}

string ReadFile(const string &in path)
{
    File@ file = g_FileSystem.OpenFile(path, OpenFile::READ);
    if (file is null || !file.IsOpen())
    {
        print("Failed to open: " + path);
        return "";
    }

    string content;
    while (!file.EOFReached())
    {
        string line;
        file.ReadLine(line);
        content += line + "\n";
    }

    file.Close();
    return content;
}

void PrintToPlayer(CBasePlayer@ plr, const string &in msg)
{
    if (plr !is null)
        g_PlayerFuncs.ClientPrint(plr, HUD_PRINTCONSOLE, msg);
    else
        print(msg);
}

string TokenTypeName(TokenType t)
{
    if (t == TokenType::LEFT_BRACE)    return "LEFT_BRACE";
    if (t == TokenType::RIGHT_BRACE)   return "RIGHT_BRACE";
    if (t == TokenType::LEFT_BRACKET)  return "LEFT_BRACKET";
    if (t == TokenType::RIGHT_BRACKET) return "RIGHT_BRACKET";
    if (t == TokenType::TRUE)          return "TRUE";
    if (t == TokenType::FALSE)         return "FALSE";
    if (t == TokenType::NULL)          return "NULL";
    if (t == TokenType::COLON)         return "COLON";
    if (t == TokenType::COMMA)         return "COMMA";
    if (t == TokenType::STRING)        return "STRING";
    if (t == TokenType::NUMBER)        return "NUMBER";
    if (t == TokenType::ERROR)         return "ERROR";
    if (t == TokenType::END_OF_FILE)   return "EOF";
    return "UNKNOWN";
}
