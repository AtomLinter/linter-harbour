{exec, child} = require 'child_process'
linterPath = atom.packages.getLoadedPackage("linter").path
Linter = require "#{linterPath}/lib/linter"

class LinterHarbour extends Linter

  @syntax: 'source.prg'


  cmd: 'harbour -w3 -es1 -q0'

  linterName: 'harbour'

  #test.prg(1) Error E0002  Redefinition of procedure or function 'TEST'
  #test.prg(3) Warning W0005  RETURN statement with no return value in function
  regex: '((?<line>\\d+)\\) ((?<error>Error)|(?<warning>Warning)) (?<message>.+)[\\n\\r]'

  constructor: (editor) ->
    super(editor)

    atom.config.observe 'linter-harbour.harbourExecutablePath', =>
      @executablePath = atom.config.get 'linter-harbour.harbourExecutablePath'

  destroy: ->
    atom.config.unobserve 'linter-harbour.harbourExecutablePath'

  errorStream: 'stderr'

module.exports = LinterHarbour
