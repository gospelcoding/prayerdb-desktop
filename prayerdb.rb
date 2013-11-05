require 'sqlite3'


def get_input(prompt)
  print prompt + '>'
  return $stdin.gets.chomp
end

def get_db
  pdb = SQLite3::Database.new('/Users/rick/dev/prayerdb/.prayer.db')
  pdb.type_translation = true
  pdb.results_as_hash = true
  pdb
end

def new_prayer
  prayer_text = get_input("Prayer")  
  pdb = get_db
  pdb.execute("INSERT INTO prayers (prayer, prayer_date, status) 
                VALUES (?,?,'current')", 
                prayer_text, Date.today.to_s)
end

def print_update_menu(menu)
  i = 1
  menu.each do |s|
    puts "#{i}: #{s.to_s.gsub('_',' ').capitalize}"
    i += 1
  end
end

def update_what(prayer)
  case prayer['status']
  when 'current'
    menu = [:mark_answered, :mark_inactive, :change_prayer, :add_tags]
  when 'inactive'
    menu = [:mark_current, :mark_answered, :add_tags]
  when 'answered'
    menu = [:change_answer, :add_tags]
  end
  
  print_update_menu(menu)
  option = get_input('Select option').to_i - 1
  return menu[option]
end

def update(plist, params)
  if params.empty?
    n = get_input("Prayer Number").to_i - 1
  else
    n = params[0].to_i - 1
  end
  
  unless (0..plist.size) === n
    puts "#{n} is not a prayer number"
    return
  end
  
  option = update_what(plist[n])
  pdb = get_db
  case option
  when :mark_answered
    answer = get_input('Answer')
    pdb.execute("UPDATE prayers SET status='answered', answer=?, answer_date=?
                  WHERE id=?", answer, Date.today.to_s, plist[n]['id'])
    return ['answered']
  when :mark_inactive
    pdb.execute("UPDATE prayers SET status='inactive' WHERE id=?", plist[n]['id'])
    return ['inactive']
  when :mark_current
    pdb.execute("UPDATE prayers SET status='current' WHERE id=?", plist[n]['id'])
    return []
  when :change_prayer
    prayer = get_input('New prayer')
    pdb.execute("UPDATE prayers SET prayer=? WHERE id=?", prayer, plist[n]['id'])
    return []
  when :change_answer
    answer = get_input('New answer')
    pdb.execute("UPDATE prayers SET status='answered', answer=?, answer_date=?
                  WHERE id=?", answer, Date.today.to_s, plist[n]['id'])
    return ['answered'] 
  when :add_tags
    tags = get_input('Tags').scan(/\w+/)
    tags.each do |tag|
      pdb.execute("INSERT INTO tags (tag, prayer_id) VALUES(?, ?)",
                    tag, plist[n]['id'])
    end
    return tags
  end
end

def make_question_marks(num)
  s = '('
  num.times{|i| s += '?,'}
  s[s.size-1] = ')'
  return s
end

def prayer_list(sql, params=[])
  pdb = get_db
  index = 1
  prayers = pdb.execute(sql, params).uniq{|p| p['id']}
  prayers.each do |prayer|
    s = "#{index}: (#{prayer['prayer_date']}) #{prayer['prayer']}" 
    s += " - (#{prayer['answer_date']}) #{prayer['answer']}" if prayer['status'] == 'answered'
    puts s
    index += 1   
  end
  return prayers
end

def list_with_tags(status_array, tag_array)
  sql = "SELECT * FROM prayers INNER JOIN tags ON prayers.id=tags.prayer_id WHERE "
  unless status_array.empty?
    sql += "prayers.status IN " + make_question_marks(status_array.size) + " AND "
  end
  sql += "tags.tag IN " + make_question_marks(tag_array.size)
  return prayer_list(sql, status_array + tag_array)
end

def list(params=[])
  if params.size < 1
    return prayer_list("SELECT * FROM prayers WHERE status='current'") 
  else
    status_array = []
    tag_array = []
    params.each do |input|
      if ['current', 'answered', 'inactive'].include?(input)
        status_array << input
      else
        tag_array << input
      end
    end
    if tag_array.empty?
      sql = "SELECT * FROM prayers WHERE status IN " + make_question_marks(status_array.size)
      return prayer_list(sql, status_array)
    else
      return list_with_tags(status_array, tag_array)
    end
  end
end

def help
  puts "new: Add a new prayer"
  puts "update: Update an existing prayer, use the listed number"
  puts "list: list prayers. List by status of current, answered or inactive; or list by tags"
  puts "quit: self-explanatory"
end




######    script starts here     #################

plist = list()

done = false
while(!done) do
  cmd = get_input('').scan(/\w+/)
  case cmd[0].downcase
  when 'new'
    new_prayer()
    plist = list()
  when 'list'
    plist = list(cmd[1..cmd.size])
  when 'update'
    params = update(plist, cmd[1..cmd.size])
    plist = list(params)
  when 'quit'
    done = true
  else
    help()
  end
end