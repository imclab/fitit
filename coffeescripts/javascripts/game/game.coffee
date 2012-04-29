window.every = (t, f) -> setInterval f, t

window.FitItGame = FitItGame = class
  constructor: (io) ->
    @socket = io.connect "http://#{window.location.hostname}:8080"
    @socket.on "connect", @onConnect

    @context = $('#screen').get(0).getContext('2d')

  onConnect: =>
    @socket.on "gamedata", @onGamedata
    @socket.on "move", @onPlayerMoved
    @socket.on "player_join", @onPlayerJoined
    @socket.on "player_leave", @onPlayerLeave
    @bindKeys()

  startAnimationLoop: ->
    every 1000 / 30, =>
      @draw()
    # requestAnimationFrame = window.requestAnimationFrame || window.mozRequestAnimationFrame ||window.webkitRequestAnimationFrame || window.msRequestAnimationFrame
    # start = window.mozAnimationStartTime # Only supported in FF. Other browsers can use something like Date.now().  
    # step = (timestamp) =>
    #   @draw()
    #   requestAnimationFrame(step)
    # requestAnimationFrame(step)

  onGamedata: (data) =>
    @board = new FitItBoard
    @board.initialize @context, data.board

    @players = {}
    for key, player of data.players
      newPlayer = new FitItPlayer @context, player
      @players[player.id] = newPlayer

    @startAnimationLoop()

  bindKeys: ->
    $(document).unbind "keydown"
    $(document).keydown (event) =>
      switch event.keyCode
        when 37 # arrow left
          @socket.emit 'move', 2
          return false
        when 38 # arrow up
          @socket.emit 'move', 3
          return false
        when 39 # arrow right
          @socket.emit 'move', 0
          return false
        when 40 # arrow down
          @socket.emit 'move', 1
          return false
        when 32 # space
          @socket.emit 'rotation', 1
          return false
        when 70 # flip
          @socket.emit 'flip'
          return false
        
  onPlayerMoved: (playerData) =>
    if @players.hasOwnProperty(playerData.id)
      @players[playerData.id].playerData = playerData

  onPlayerJoined: (playerData) =>
    @players[playerData.id] = new FitItPlayer @context, playerData

  onPlayerLeave: (playerData) =>
    i = 0
    for key, player of @players
      if parseInt(key) is parseInt(playerData.id)
        delete @players[playerData.id]
        break
      i++

  draw: ->
    @context.clearRect @context.width, @context.height
    @board.draw()
    for key, player of @players
      player.draw()

