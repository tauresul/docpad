# Export Plugin
module.exports = (BasePlugin) ->
	# Requires
	balUtil = require('bal-util')
	jsdom = require('jsdom')
	{spawn,exec} = require('child_process')
	

	# Pygmentize some source code
	# next(err,result)
	pygmentizeSource = (source, language, next) ->
		# Prepare
		result = ''
		errors = ''
		args = ['-f', 'html', '-O', 'encoding=utf-8']

		# Language
		if language
			args.unshift(language)
			args.unshift('-l')
		else
			args.unshift('-g')

		# Spawn Pygments
		pygments = spawn 'pygmentize', args
		pygments.stdout.on 'data', (data) ->
			result += data.toString()
		pygments.stderr.on 'data', (data) ->
			errors += data.toString()
		pygments.on 'exit', ->
			return next(new Error(errors))  if errors
			return next(null,result)

		# Start highlighting
		pygments.stdin.write(source)
		pygments.stdin.end()

	# Pygmentize an element
	# next(err)
	pygmentizeElement = (window, element, next) ->
		# Prepare
		parentNode = element
		childNode = element
		source = false
		language = false

		# Is our code wrapped  inside a child node?
		if element.childNodes.length and String(element.childNodes[0].tagName).toLowerCase() in ['pre','code']
			childNode = element.childNodes[0]

		# Is our code wrapped in a parentNode?
		else if element.parentNode.tagName in ['pre','code']
			parentNode = element.parentNode

		# Grab the source
		source = childNode.innerHTML
		language = childNode.getAttribute('lang') or parentNode.getAttribute('lang')

		# Trim language
		language = language.replace(/^\s+|\s+$/g,'')

		# Pygmentize
		pygmentizeSource source, language, (err,result) ->
			return next(err)  if err
			resultEl = window.document.createElement('div')
			resultEl.innerHTML = result
			element.parentNode.replaceChild(resultEl.childNodes[0],element)
			return next()

	# Define Plugin
	class PygmentsPlugin extends BasePlugin
		# Plugin Name
		name: 'pygments'
		
		# Render the document
		renderDocument: ({file,extension,templateData},next) ->
			if extension is 'html'
				# Create DOM from the file content
				jsdom.env(
					html: "<html><body>#{file.content}</body></html>"
					features:
						QuerySelector: true
					done: (err,window) ->
						return next?(err)  if err

						# Find highlightable elements
						elements = window.document.querySelectorAll(
							'code pre, pre code, .highlight'
						)

						# Check
						if elements.length is 0
							return next() # nothing to do!!!! REMEMBER THIS!!!

						# Tasks
						tasks = new balUtil.Group (err) ->
							return next(err)  if err
							# Apply the content
							file.content = window.document.body.innerHTML
							# Completed
							return next()
						tasks.total = elements.length

						# Syntax highlight those elements
						for value,key in elements
							element = elements.item(key)
							pygmentizeElement window, element, tasks.completer()
				)
			else
				return next()