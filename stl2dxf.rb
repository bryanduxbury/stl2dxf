# require "rubygems"
# require "dxf"

input_file = ARGV.shift

triangles = []

File.open(input_file, "r") do |file|
  while line = file.gets
    if line =~ /^  facet normal/
      triangle = {
        n: line.strip.split(" ")[2...5].map(&:to_f)
      }

      line = file.gets # "outer loop"
      triangle[:v] = [file.gets, file.gets, file.gets].map do |l| 
        l.strip.split(" ")[1..-1].map(&:to_f)
      end

      triangles << triangle
    end
  end
end

$stderr.puts "#{triangles.size} triangles loaded"

z_levels = triangles.map {|t| t[:v].map{|vert| vert[2]}}.flatten.uniq

$stderr.puts "#{z_levels.size} slice planes"

triangles_in_plane = triangles.select do |t|
  t[:v][0][2] == t[:v][1][2] && t[:v][0][2] == t[:v][2][2]
end

$stderr.puts "#{triangles_in_plane.size} triangles found in xy plane"

triangles_by_slice = triangles_in_plane.group_by do |t|
  t[:v][0][2]
end

triangles_by_slice.keys.sort.each do |slice|
  $stderr.puts "#{triangles_by_slice[slice].size} triangles in slice #{slice}"
end

edges_by_slice = {}

def reorder_edge(a,b)
  if a[0] == b[0]
    if a[1] < b[1]
      [a, b]
    else
      [b, a]
    end
  elsif a[0] < b[0]
    [a, b]
  else
    [b, a]
  end
end

all_xs = triangles_in_plane.map{|t| t[:v]}.flatten(1).map{|vert| vert[0]}.sort
min_x = all_xs.first
max_x = all_xs.last

width = max_x - min_x

all_ys = triangles_in_plane.map{|t| t[:v]}.flatten(1).map{|vert| vert[1]}.sort
min_y = all_ys.first
max_y = all_ys.last

height = max_y - min_y

triangles_by_slice.each do |slice, ts|
  edges_in_slice = ts.map do |t|
    vs = t[:v].map{|v| v[0..1]}
    [reorder_edge(vs[0],vs[1]), reorder_edge(vs[1],vs[2]), reorder_edge(vs[2],vs[0])]
  end
  edges_in_slice.flatten!(1)

  edges_in_slice = edges_in_slice.group_by {|edge| edge}.select do |edge, instances|
    instances.size == 1
  end.keys
  
  edges_by_slice[slice] = edges_in_slice
  
  $stderr.puts "#{edges_in_slice.size} edges in slice #{slice}"

  File.open("layer_#{slice}.svg", "w") do |f|
    f.puts <<-EOF
    <svg 
      xmlns:dc="http://purl.org/dc/elements/1.1/"
      xmlns:cc="http://creativecommons.org/ns#"
      xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
      xmlns:svg="http://www.w3.org/2000/svg"
      xmlns="http://www.w3.org/2000/svg"
      version="1.1"
      width="#{width}mm"
      height="#{height}mm"
      viewBox="0 0 #{width} #{height}"
    >
    <g>
    <rect width="#{width}" height="#{height}" style="fill:none; stroke:green; stroke-width:0.1mm" />
    EOF
    edges_in_slice.each do |e|
      f.puts "<path d='M #{e[0][0] - min_x},#{e[0][1] - min_y} L #{e[1][0] - min_x},#{e[1][1] - min_y}' style='stroke: #000000; stroke-width: 0.1mm'/>"
    end
    f.puts "</g></svg>"
  end

  # sketch = Sketch.new
  # edges_in_slice.each do |e|
  #   sketch.push(Geometry::Edge.new(e[0], e[1]))
  # end

  # DXF.write("layer_#{slice}.dxf", sketch, :mm)
end

# edges_in_plane = triangles_in_plane.map do |t|
#   vs = t[:v]
#   ret = []
#   ret << [vs[0],vs[1]]
#   ret << [vs[1],vs[2]]
#   ret << [vs[2],vs[3]]
# end
#
# edges_in_plane.flatten!(1)
#
# $stderr.puts "#{edges_in_plane.size} edges in xy plane"