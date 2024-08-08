# Nomicon

Nomicon is an [Ink](https://www.inklestudios.com/ink/) runtime for Lua, especially [LÖVE](https://love2d.org/) (though LÖVE is not a requirement). Compile your script with Inklecate and run it with the easy to use Nomicon API!

## Getting Started

Add the `nomicon` folder to your project... somewhere. Run your story like so:

```lua
local json = require "json" -- for example, see https://github.com/rxi/json.lua
local Nomicon = require "nomicon"

local book = json.decode(love.filesystem.read("demo.json"))
local story = Nomicon.Story(book)
local choices = Nomicon.ChoiceList(story)

while story:canContinue() do
  local text = story:continue()
  print(text)

  if choices:hasChoices() then
    for i = 1, choices:getChoiceCount() do
      local choice = choices:getChoice(i)
      print(string.format("%d. %s", i, choice:getText()))
    end

    local choiceIndex
    repeat
      io.write("> ")

      local input = io.read()
      choiceIndex = tonumber(input)

      if not choiceIndex then
        print("Please enter a choice number.")
      elseif not (choiceIndex >= 1 and choiceIndex <= choices:getChoiceCount()) then
        print(string.format("Please enter a choice from 1 through %d.", choices:getChoiceCount()))
      end
    until choiceIndex and choiceIndex >= 1 and choiceIndex <= choices:getChoiceCount()

    choices:getChoice(choiceIndex):choose()
  end
end

print("The End.")
```

See the API documentation in the source or README for more info.

## API

### `Nomicon.Story`

* `Nomicon.Story(book, defaultGlobalVariables = {})`: Construct a new `Nomicon.Story` instance with the provided book JSON marshalled to a Lua table. `defaultGlobalVariables` overrides global variables initialized in the Ink script - use with care!

* `Nomicon.Story:getGlobalVariable(variableName, marshal = true)`: Gets the current value of a global variable. If `marshal` is false (it defaults to true), then the underlying `Nomicon.impl.Value` will be returned; otherwise, the direct value will be returned. `Nomicon.impl.Value` is **read-only** and a reference is only valid until the next `Nomicon.Story:setGlobalVariable` with that variable name. So clone it if you want to keep it around.

* `Nomicon.Story:setGlobalVariable(variableName, value)`: Sets a global variable. Any global variable listeners **will not** be fired.

* `Nomicon.Story:listenForGlobalVariable(variableName, func, marshal = true, ...)`: Listens for a change on the global variable `variableName`. `func` will be called differently depending on the value for `variableName`. All extra parameters will be passed in as the first parameters to `func` using magic. If `func` returns a value, it will be marshalled to a valid Ink value (or error on failure).
  If `marshal` is false, the underlying `Nomicon.impl.Value` objects will be provided. Like with `Nomicon.Story:getGlobalVariable()`, these values are only valid during the function call. Clone them if you want to keep them around!
  Multiple listeners can be attached, but only the return value of the last listener registered will be used to override a variable assignment.
  * If `variableName` was `"*"`, then `func` will be called like: `func(..., variableName, currentValue, previousValue)`
  * If `variableName` was not `"*"`, then `func` will be called like this: `func(..., currentName, previousValue)`.

* `Nomicon.Story:silenceGlobalVariableListener(variableName, func)`: Silences the global variable listener `func` for `variableName`. If `func` is true, then **all** listeners will be silenced for `variableName`.

* `Nomicon.Story:hasExternalFunction(name)`: Returns true if an external function with name `name` has been registered; false otherwise.

* `Nomicon.Story:freeExternalFunction(name)`: Removes the external function with `name`. If it is called by the code, the game will silently return `Value.VOID` which may have unforeseen consequences.

* `Nomicon.Story:bindExternalFunc(name, func, marshal = true, ...)`: If an external function with `name` has yet to be bound, then this will bind `func` to name. Like the global variable listeners, all extra values will be passed **first** to `func` followed by the arguments provided by the script. If `marshal` is true (the default), then these values will be marshalled from `Nomicon.impl.Value`; otherwise, they will not. The arguments, if they are `Nomicon.impl.Value`, are only valid until the function returns, so if you store them as un-marshalled values, clone them!

* `Nomicon.Story:canContinue()`: Returns true if the story can continue; false otherwise.

* `Nomicon.Story:continue(yield = false)`: Continues the story. Returns the current line of text and the tags associated with the that line of text. If `yield` is true, then the story will yield nothing after each "step" (execution cycle: get next instruction, advance pointer, check if done). Until this method returns, any mutations on `Nomicon.Story` are not allowed. This includes, but is not necessarily limited to:
  * Setting a global variable or listening for a global variable
  * Binding an external function
  * 

* `Nomicon.Story:hasChoices()`: Returns true if there is at least one choice available, false otherwise. This includes **unselectable** choices. If you only want to manage visible and selectable choices, see `Nomicon.ChoiceList`.

* `Nomicon.Story:getChoice(index)`: Returns the choice at the provided index. This will be a `Nomicon.impl.Choice`, which is lower-levelled than `Nomicon.Choice` and exposes some intrinsic, internal state about the choice.

* `Nomicon.Story:getTagCount()`: Returns the number of tags associated with the last line of text.

* `Nomicon.Story:getTag(index)`: Returns the tag at the provided index. Negative values will wrap, so passing in `-1` will return the last tag.

* `Nomicon.Story:getGlobalTagCount()`: Returns the number of global tags associated with the story.

* `Nomicon.Story:getGlobalTag(index)`: Returns the global tag at the provided index. Like `getTag`, negative values wrap.

* `Nomicon.Story:getTags(path)`: Returns an array of the tags that start prior to content at `path`. This runs in a separate flow (see below) so the current execution state isn't affected.

* `Nomicon.Story:choose(option, ...)`: Increments the turn count and switches to the knot/container at `option` (if the argument is a string) or chooses a specific choice (if the argument is a `Nomicon.impl.Choice`). Any extra arguments are passed are passed onto the stack to the knot.

* `Nomicon.Story:call(func, marshal = true, yield = false, ...)`: Calls `func` with `...` args. Returns the content, tags, and any return values (will probably be one, but who knows in the future...). The call is executed in a temporary flow independent of the current flow for safety. If `func` errors, this flow will safely be disposed of and then the error will bubble up. Values will be marshalled from `Nomicon.impl.Value` if `marshal` is true; if not, they will be returned untouched. Keep in mind these unmarshalled values are only valid until the next method that modifies the story state in any way - so clone them if you want to keep them around! `yield` makes this function yield at each instruction cycle while executing the function.

* `Nomicon.Story:getTurnCount()`: Returns the current turn count of the story. Turn count increments with every action or call to `Nomicon.Story:choose`.

#### Flows

Flows are mostly independent executions of the story. Only global variables, turn/visit counts,  external functions, and RNG are shared.

* `Nomicon.Story:newFlow(name)`: Creates a new flow with the given name but does not switch to it. Returns true if the flow was successfully created (i.e., `name` was not used or `"default"`), false otherwise.

* `Nomicon.Story:deleteFlow(name)`: Deletes a flow with the given name. The `"default"` flow cannot be deleted. If this flow is the current flow, will switch back to the default flow. Returns true if the flow was deleted (i.e., `name` was not used or `"default"`), false otherwise.

* `Nomicon.Story:hasFlow(name)`: Returns true if there is a flow with the given name.

* `Nomicon.Story:flows()`: Returns an iterator over the order (index) and name of the flows. The order (index) has no functional effect; it just represents the order the flow was created relative to each other flow.

* `Nomicon.Story:getCurrentFlowName()`: Returns the current flow's name.

### `Nomicon.ChoiceList` / `Nomicon.Choice`

Generally you should use the `Nomicon.ChoiceList` API over directly querying the `Nomicon.Story`. You'd only want to use `Nomicon.Story`'s choices if you want them to be visible (i.e., greyed out) when unselectable.

* `Nomicon.ChoiceList(story)`: Constructs a new ChoiceList. The choices will automatically update with every update to the `Nomicon.Story`, even with flow switches, etc.

* `Nomicon.ChoiceList:hasChoices()`: Returns true if there is at least one selectable and visible option.

* `Nomicon.ChoiceList:getChoiceCount()`: Returns the count of visible and selectable choices.

* `Nomicon.ChoiceList:getChoice(index)`: Returns the `Nomicon.Choice` (not to be confused with `Nomicon.impl.Choice`) at the index. Negative values wrap around, so -1 would return the last selectable and visible choice.

#### `Nomicon.Choice`
This is a light-weight wrapper over `Nomicon.impl.Choice`.

* `Nomicon.Choice:getIndex()`: Returns the index into the parent `Nomicon.ChoiceList` (**not the same as the index into the `Nomicon.Story` `getChoiceCount()/getChoice()` methods!**).

* `Nomicon.Choice:choose()`: Chooses this choice. Internally calls `Nomicon.Story:choose()` with the `Nomicon.impl.Choice` this wraps.

* `Nomicon.Choice:getText()`: Returns the visible text of the choice.

* `Nomicon.Choice:getTagCount()`: Returns the tag count.

* `Nomicon.Choice:getTag(index)`: Gets the tag at the provided index. Like everything else, a negative value wraps, so -1 returns the last tag.

### Advanced API
* `Nomicon.Story:getListDefinitions()`: Gets the list definitions interface. This allows you to programmatically create lists at runtime, e.g. via external functions or setting global variables. See documentation in `nomicon/impl/ListDefinitions.lua`.

* `Nomicon.Story:setRandom(setSeedFunc, getSeedFunc, random)`: Override the default RNG. Nomicon will use LÖVE's RNG internally if available with the default seed. `setSeedFunc` takes a number and sets the seed; `getSeedFunc` returns the current seed that can be set in `setSeedFunc`; and `random` takes `min` and `max` and returns a number from `[min, max]`.

* `Nomicon.Story:setRandomSeed(seed)`: Sets the random seed of the RNG.

* `Nomicon.Story:getRandomSeed()`: Returns the current random seed from the RNG.

* `Nomicon.Story:random(min, max)`: Returns a random integer (inclusive) between min and max.

### License

This project is licensed under the MPL. View LICENSE in the root directory or
visit http://mozilla.org/MPL/2.0/ for the terms.
