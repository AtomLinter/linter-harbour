{CompositeDisposable} = require 'atom'
{exec, tempFile} = helpers = require('atom-linter')
path = require 'path'
ExePath = require('./util/exepath')

VALID_SEVERITY = ['error', 'warning', 'info']

getSeverity = (givenSeverity) ->
  severity = givenSeverity.toLowerCase()
  return if severity not in VALID_SEVERITY then 'warning' else severity

module.exports =
  config:
    additionalArguments:
      title: 'Additional arguments for harbour compiler'
      description: 'e.g. -w3 -es1 -i /usr/local/include/harbour ' +\
       '-i /build/myproj/include'
      type: 'string'
      default: '-w3 -es1'
    executablePath:
      type: 'string'
      title: 'harbour compiler Executable'
      default: 'harbour'

  _testBin: ->
    title = 'linter-harbour: Unable to determine harbour version'
    message = 'Unable to determine the version of "' + @executablePath +
      '", please verify that this is the right path to harbour.'
    try
      exePath = new ExePath()
      @executablePath = exePath.full(@executablePath)
      helpers.exec(@executablePath, ['--version']).then (output) =>
        # Harbour 3.2.0dev (r1408271619)
        regex = /Harbour (\d+.*) /g
        if not regex.exec(output)
          atom.notifications.addError(title, {detail: message})
          @executablePath = ''
      .catch (e) ->
        console.log e
        atom.notifications.addError(title, {detail: message})

  activate: ->
    require('atom-package-deps').install('linter-harbour')
    .then ->
    console.log("All linter-harbour deps are installed :)")

    @subscriptions = new CompositeDisposable
    @subscriptions.add atom.config.observe 'linter-harbour.executablePath',
      (executablePath) =>
        @executablePath = executablePath
        @_testBin()
    @subscriptions.add atom.config.observe 'linter-harbour.additionalArguments',
      (additionalArguments) =>
        @additionalArguments = additionalArguments
    console.log "linter-harbour activated"

  deactivate: ->
    @subscriptions.dispose()

  provideLinter: ->
    provider =
      name: 'harbour'
      grammarScopes: [ 'source.harbour' ]
      scope: 'file'
      lintsOnChange: yes
      lint: (textEditor) =>
        filePath = textEditor.getPath()
        cwd = path.dirname(filePath)
        command = @executablePath
        return Promise.resolve([]) unless command?
        parameters = []
        parameters.push('-n', '-s', )
        text = textEditor.getText()
        tempFile path.basename(filePath), text, (tmpFilePath) =>
          params = [
            tmpFilePath,
            '-n',
            '-s',
            '-q0',
            @additionalArguments.split(' ')...
          ].filter((e) -> e)
          return helpers.exec(command, params, {cwd: cwd}).then (output) ->
            return []
          .catch (output) ->
            #console.log "stderr output:", output
            # test.prg(3) Error E0030  Syntax error "syntax error at '?'"
            # test.prg(8) Error E0020  Incomplete statement or unbalanced delim
            regex = /([\w\.]+)\((\d+)\) (Error|Warning) ([\w\d]+) (.+)/g
            returnMessages = []
            while((match = regex.exec(output)) isnt null)
              try

                matchLine = match[5].match(/\((\d+)\)/)
                if matchLine
                  range = helpers.generateRange(textEditor, Number.parseInt(matchLine[1], 10) - 1)
                else
                  range = helpers.generateRange(textEditor, Number.parseInt(match[2], 10) - 1)

                returnMessages.push
                  severity: getSeverity(match[3])
                  excerpt: match[4] + ': ' + match[5]
                  location:
                    file: filePath
                    position: range
              catch e
                console.log e
            returnMessages

