
namespace StateMachine{
    class StateMachine{
        private string currentState;
        private dictionary transitions;
        private bool ready = false;

        StateMachine(){
            currentState = "NONE";
        }

        StateMachine(const dictionary possibleStates, const string initialState){
            currentState = initialState;
            transitions = possibleStates;
            ready = true;
        }

        StateMachine(const array<string>@ possibleStates, const string initialState) {
            currentState = initialState;

            for (uint i = 0; i < possibleStates.length(); i++){
                string state = possibleStates[i];
                @transitions[string(state)] = array<string> = {};
            }
            ready = true;
        }

        private bool CanChange(string state){
            array<string>@ valid;
            if (transitions.get(string(currentState), @valid)){
                if (valid is null){
                    return false;
                }
                if (valid.find(state) >= 0){
                    return true;
                }
            }			
            return false;
        }

        void Update(string state){
            if (!CanChange(state)){
                print("Can't switch to: " + state + " from " + currentState + " no valid transition...");
                return;
            }
            currentState = state;
        }

        void AddTransition(const string key, const string val){
            array<string>@ valid;
            if (!transitions.get(string(key), @valid)){
                print("Failed to add Transition, " + key + " is not part of the StateMachine");
            }
            if (valid is null){
                print("Found a valid key, but no state array? BUG");
            }

            valid.insertLast(val);
        }
        void AddTransition(const string key, const array<string>@ arr){
            array<string>@ valid;
            if (!transitions.get(string(key), @valid)){
                print("Failed to add Transition, " + key + " is not part of the StateMachine");
            }
            if (valid is null){
                print("Found a valid key, but no state array? BUG");
            }

            // could add a duplicate check, but probably will switch to using dicts later;
            for (uint i = 0; i < arr.length(); i++){
                valid.insertLast(arr[i]);
            }
        }  


        string GetState() const {
            return currentState;
        }
        bool IsReady() const{
            return ready;
        }

    }
}
