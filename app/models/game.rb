class Game < ActiveRecord::Base
  attr_accessible :name, :status, :players_attributes, :starting_player
  has_many :players
  has_many :users, through: :players
  has_many :moves, through: :players
  has_many :scores

  accepts_nested_attributes_for :players

  before_save :set_starting_player

######## Class methods to return game sets ########

  def self.find_games_for(user)
    self.joins(players: :user).where(users: {id: user.id})
  end

  def self.users_games(user)
    find_games_for(user).where(status: [nil, 'pending'])
  end

  def self.games_to_join(user)
    self.joins(:players).where(starting_player: nil).where("players.user_id != ?", user.id)
  end

  def self.completed_games(user)
    find_games_for(user).where('status = ? OR status = ?', 'win', 'draw')
  end

  def winning_user
    User.joins({players: :scores}, {players: :game}).where('games.id=?', self.id).where(scores: {result: 'win'})
  end

####### Game methods ########

  def make_move(location)
    current_player.moves.create(grid_location: location)
    computer_move
  end

  def computer_move
    if current_player.user.name == 'Computer' && !completed?
      current_player.moves.create(grid_location: available_moves.sample)      
    end
  end

  def available_moves
    moves = []
    game_state.each_index { |i| moves << i if game_state[i].nil? }
    moves
  end

  def capacity?
    players.reject(&:new_record?).length < 2
  end

  def playing?(id)
    players.reject(&:new_record?).map(&:user_id).include?(id)
  end

  def game_state
      state = [nil]*9
      players(true).each do |player|
    
        if player.moves(true).any?
          symbol = player.symbol
          locations = player.moves.map(&:grid_location)
          locations.each { |i| state[i] = symbol }
        end
    
      end
    state
  end

  def users_turn?(user)
    current_player.try(:user) == user
  end

  def last_player
    moves.order('created_at DESC').limit(1).first.try(:player)
  end

  def current_player
    if last_player
      players.where('id != ?', last_player.id).first
    else
      Player.find_by_id(starting_player)
    end
  end


  ########### Tic Tac Toe Logic #########################

  WIN_LINES = [
    [0,1,2],
    [3,4,5],
    [6,7,8],
    [0,3,6],
    [1,4,7],
    [2,5,8],
    [0,4,8],
    [2,4,6]
    ]

  def winner
    WIN_LINES.each do |line|
      current_line = [ game_state[line[0]], game_state[line[1]], game_state[line[2]] ]
      
      unless current_line.include?(nil)
        current_line.uniq.length == 1 ? (return line) : nil
      end
    end
    nil
  end

  def who_won
    players.joins(:scores).where("scores.result = 'win'").first
  end

  def who_lost
    players.joins(:scores).where("scores.result = 'lose'").first

  end

  def completed?
    ['win', 'draw'].include?(status)
  end

  def result
    if winner
      "Winner is #{who_won.user.name}"
    elsif !game_state.include?(nil)
      "Draw. No winner."
    end
  end

  def set_starting_player
    unless capacity?
      self.starting_player ||= players.sample.id
    end
  end

  def update_game_status
    if winner
      create_scores_for_win
      self.status = :win
    elsif !game_state.include?(nil)
      create_score_for_draw
      self.status = :draw
    else
      self.status = :pending
    end
    save
    puts "updated status to #{status}"
    status
  end

  def create_scores_for_win
    unless completed?
      scores.create(player_id: current_player.id, result: 'lose')
      scores.create(player_id: last_player.id, result: 'win')
    end
  end

  def create_score_for_draw
    unless completed?
      scores.create(player_id: current_player.id, result: 'draw')
      scores.create(player_id: last_player.id, result: 'draw')
    end
  end

end