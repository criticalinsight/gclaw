{application, gleam_hackney, [
    {vsn, "1.3.3"},
    {applications, [gleam_http,
                    gleam_stdlib,
                    hackney]},
    {description, "Gleam bindings to the Hackney HTTP client"},
    {modules, [gleam@hackney,
               gleam_hackney_ffi]},
    {registered, []}
]}.
