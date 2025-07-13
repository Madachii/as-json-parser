#include "StateMachine"

// A very broken implementation of a json parser, completly can't recognize int, array or anything

namespace JSON{

    dictionary states = {
		{"NONE", array<string> = {"STRING"}},
        {"STRING", array<string> = {"ASSIGN", "NEXT", "END"}},
	    {"ASSIGN", array<string> = {"ARRAY", "STRING", "RECURSE"}},
	    {"RECURSE", array<string> = {"STRING", "END"}},
        {"END", array<string> = {"NEXT", "STRING", "END"}},
        {"NEXT", array<string> = {"STRING", "END"}},
        {"ARRAY", array<string> = {"STRING"}}
    };

    StateMachine::StateMachine state(states, "NONE");

    class JSON
    {
        private dictionary map;
        private uint index;

        JSON(){}
        JSON(const string str){
            this = ParseJson(str);
        }

        dictionary GetMap(){
            return map;
        }

        bool Exists(const string key){
            return map.exists(key);
        }
        void Add(const string key, const string val){
            map[key] = val;
        }
        void Add(const string key, const JSON val){
            map[key] = val;
        }
        JSON@ AddLevel(const string key){
            if (!map.exists(key)){
                map[key] = JSON();
            }
            return cast<JSON>(map[key]);
        }
        string Get(const string key) const{
            if (Exists(key)){
                return string(map[key]);
            }
            return "";
        }
        
        void UpdateState(const string val){
            state.Update(val);
        }

        JSON@ get_opIndex(const string key){
            JSON@ json;
            bool isValid = map.get(key, @json);
            if (isValid){
                return json;
            }
            else{
                return AddLevel(key);
            }
        }
        
    }

    JSON ParseJson(const string str){
        int index = 0;
        JSON@ json = _ParseJson(str, index, index);
        return json;
    }

    // gotta love that they disabled passing primitives by reference... doing this instead....
    JSON _ParseJson(const string str, uint &in inIndex, uint &out outIndex){
        JSON current;
        string key;
        outIndex = inIndex;	

        while (++outIndex < str.Length()){	
            int ch = str[outIndex];  
            string buffer;
            switch (ch) {
                case 32: // ' ' 
                    continue;

                case 34:  // "
                    state.Update("STRING");

                    while (str[++outIndex] != '"') {
                        buffer += str[outIndex];
                    }

                    if (!key.IsEmpty()) {
                        current.Add(key, buffer);
                        key = "";
                    } else {
                        key = buffer;
                    }
                    break;

                case 44: // ,  
                    state.Update("NEXT");
                    break;

                case 58: // : 
                    state.Update("ASSIGN");
                    break;

                case 123: // { 
                    if (key.IsEmpty()) {
                        print("Invalid JSON");
                    }
                    state.Update("RECURSE");
                    current.Add(key, _ParseJson(str, ++outIndex, ++outIndex));
                    key = "";
                    break;

                case 125: // } 
                    state.Update("END");
                    ++outIndex;
                    return current;

                default:
                    break;
            }
        }
        return current;
    }

    // wrapper cuz having to use both in / out is so ugly
    string GetFull(JSON@ json){
        string result = "{\n";
        int level = 1;
        array<JSON@> jsonArr = {json};

        _GetFull(jsonArr, result, result, level);

        result += "}";
        return result;
    }

    // don't call directly, use wrapper
    string _GetFull(array<JSON@> &inout json, string &in inResult, string &out outResult, int level){
        string padding = "";
        outResult = inResult;

        if (json.length() != 0){

            for (int i = 0; i < level; i++){
                padding += "    ";
            }
            JSON@ dict = json[0];
            dictionary dictMap = dict.GetMap();

            json.removeAt(0);
            if (dictMap !is null){
                array<string>@ keys = dictMap.getKeys();

                for (uint i = 0; i < keys.length(); i++){
                    string text = string(dictMap[keys[i]]);
                    if (!text.IsEmpty()){
                        outResult += padding + "\"" + keys[i] + "\"" + ": " + "\"" + text + "\"" + ",\n";
                        continue;
                    }

                    JSON@ newDict;
                    if (dictMap.get(keys[i], @newDict)){
                        outResult += padding + "\"" + keys[i] + "\"" + ":" + "{\n";
                        json.insertLast(newDict);
                        _GetFull(json, outResult, outResult, level + 1);
                        outResult += padding + "}\n";
                    }
                }
            }
        }
        return outResult;
    }
    void Save(JSON@ json, const string path){
        string result = GetFull(json);

        File@ file = g_FileSystem.OpenFile(path, OpenFile::WRITE);
        if (file is null || !file.IsOpen()){
            print("Failed to open file");
            return;
        }

        file.Write(result);
        file.Close();
    }
}