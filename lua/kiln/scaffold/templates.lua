-- lua/kiln/scaffold/templates.lua

local M = {}

local BODIES = {}

BODIES.class = function(name)
  return string.format([[
public class %s
{
}
]], name)
end

BODIES.interface = function(name)
  return string.format([[
public interface I%s
{
}
]], name)
end

BODIES.struct = function(name)
  return string.format([[
public struct %s
{
}
]], name)
end

BODIES.enum = function(name, opts)
  local values = opts and opts.values or {}
  local body = ""
  if #values > 0 then
    body = "    " .. table.concat(values, ",\n    ")
  end
  return string.format([[
public enum %s
{
%s
}
]], name, body)
end

BODIES.record = function(name, opts)
  local params = opts and opts.params or {}
  return string.format([[
public record %s(%s);
]], name, table.concat(params, ", "))
end

BODIES.exception = function(name)
  return string.format([[
public class %sException : Exception
{
    public %sException() { }
    public %sException(string message) : base(message) { }
    public %sException(string message, Exception inner) : base(message, inner) { }
}
]], name, name, name, name)
end

BODIES.entity = function(name)
  return string.format([[
using System.ComponentModel.DataAnnotations;

public class %s
{
    [Key]
    public int Id { get; set; }
}
]], name)
end

BODIES.controller = function(name)
  return string.format([[
using Microsoft.AspNetCore.Mvc;

[ApiController]
[Route("api/[controller]")]
public class %sController : ControllerBase
{
    [HttpGet]
    public IActionResult Get() => Ok(new { message = "Hello from %s" });

    [HttpGet("{id}")]
    public IActionResult GetById(int id) => Ok(new { id });

    [HttpPost]
    public IActionResult Create([FromBody] %s dto) => CreatedAtAction(nameof(GetById), new { id = 1 }, dto);
}
]], name, name, name)
end

BODIES.service = function(name)
  return string.format([[
public class %sService
{
    private readonly %sRepository _repository;

    public %sService(%sRepository repository)
    {
        _repository = repository;
    }
}
]], name, name, name, name)
end

BODIES.repository = function(name)
  return string.format([[
public class %sRepository
{
    // TODO: inject DbContext
}
]], name)
end

BODIES.worker = function(name)
  return string.format([[
using Microsoft.Extensions.Hosting;

public class %sWorker : BackgroundService
{
    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            await Task.Delay(1000, stoppingToken);
        }
    }
}
]], name)
end

function M.render(kind, ns, name, opts)
  local body = BODIES[kind]
  if not body then return nil end
  local out = {}
  if ns and ns ~= "" then
    out[#out+1] = "namespace " .. ns .. ";"
    out[#out+1] = ""
  end

  -- imports per kind
  if kind == "controller" then
    out[#out+1] = "using Microsoft.AspNetCore.Mvc;"
    out[#out+1] = ""
  elseif kind == "worker" then
    out[#out+1] = "using Microsoft.Extensions.Hosting;"
    out[#out+1] = ""
  end

  out[#out+1] = body(name, opts)
  return table.concat(out, "\n")
end

return M
