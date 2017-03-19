{CompositeDisposable} = require 'atom'
{exec, tempFile} = helpers = require('atom-linter')
path = require 'path'
ExePath = require('./util/exepath')

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
    require('atom-package-deps').install()
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
      lintOnFly: yes
      lint: (textEditor) =>
        #console.log "linter-harbour start"
        filePath = textEditor.getPath()
        cwd = path.dirname(filePath)
        command = @executablePath
        #console.log "command:", command
        return Promise.resolve([]) unless command?
        parameters = []
        parameters.push('-n', '-s', )
        text = textEditor.getText()
        #console.log "text:", text
        tempFile path.basename(filePath), text, (tmpFilePath) =>
          #console.log "filePath:", filePath, "tmpFilePath:", tmpFilePath
          params = [
            tmpFilePath,
            '-n',
            '-s',
            '-q0',
            @additionalArguments.split(' ')...
          ].filter((e) -> e)
          #console.log "command:", command, "cmd-params:", params
          return helpers.exec(command, params, {cwd: cwd}).then (output) ->
            return []
          .catch (output) ->
            #console.log "stderr output:", output
            # test.prg(3) Error E0030  Syntax error "syntax error at '?'"
            # test.prg(8) Error E0020  Incomplete statement or unbalanced delim
            regex = /([\w\.]+)\((\d+)\) (Error|Warning) ([\w\d]+) (.+)/g
            returnMessages = []
            #console.log 'output:', output
            while((match = regex.exec(output)) isnt null)
              # console.log "match:", match, "range",
              # helpers.rangeFromLineNumber(textEditor, match[2] - 1),
              # "line count:", textEditor.getLineCount()
              try
                range = helpers.generateRange(textEditor, match[2] - 1)
                returnMessages.push
                  type: match[3]
                  filePath: filePath
                  range: range
                  text: match[4] + ': ' + match[5]
              catch e
                console.log e
              #finally
              #  range[0][0] = Math.min( range[0][0], textEditor.getLineCount()-1)
              #  range[1][0] = Math.min( range[1][0], textEditor.getLineCount()-1)

            #console.log "return", returnMessages
            returnMessages
