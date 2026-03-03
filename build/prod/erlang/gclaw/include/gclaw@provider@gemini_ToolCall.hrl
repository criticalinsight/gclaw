-record(tool_call, {
    name :: binary(),
    args :: gleam@dict:dict(binary(), gleam@dynamic:dynamic_())
}).
