local api = vim.api
local filetype = require('guard.filetype')
local spawn = require('guard.spawn').try_spawn
local ns = api.nvim_create_namespace('Guard')
local get_prev_lines = require('guard.util').get_prev_lines
local vd = vim.diagnostic

local function do_lint(buf)
  buf = buf or api.nvim_get_current_buf()
  if not filetype[vim.bo[buf].filetype] then
    return
  end
  local linters = filetype[vim.bo[buf].filetype].linter
  local fname = vim.fn.fnameescape(api.nvim_buf_get_name(buf))
  local prev_lines = get_prev_lines(buf, 0, -1)
  vd.reset(ns, buf)

  coroutine.resume(coroutine.create(function()
    local results

    for _, lint in ipairs(linters) do
      lint = vim.deepcopy(lint)
      lint.args[#lint.args + 1] = fname
      lint.lines = prev_lines
      local data = spawn(lint)
      if #data > 0 then
        results = lint.output_fmt(data, buf)
      end
    end

    vim.schedule(function()
      if not api.nvim_buf_is_valid(buf) or not results or #results == 0 then
        return
      end
      vd.set(ns, buf, results)
    end)
  end))
end

local function register_lint(ft, extra)
  api.nvim_create_autocmd('FileType', {
    pattern = ft,
    callback = function(args)
      api.nvim_create_autocmd(vim.list_extend({ 'BufEnter' }, extra), {
        buffer = args.buf,
        callback = function()
          do_lint(args.buf)
        end,
      })
    end,
  })
end

local function diag_fmt(buf, lnum, col, message, severity, source)
  return {
    bufnr = buf,
    col = col,
    end_col = col,
    end_lnum = lnum,
    lnum = lnum,
    message = message,
    namespace = ns,
    severity = severity,
    source = source,
  }
end

return {
  register_lint = register_lint,
  diag_fmt = diag_fmt,
}
