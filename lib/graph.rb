require 'rubygems'
require 'rgl/adjacency'

module RGL
  class Edge::DirectedEdge
    # Takes a source, target, and a reference to the terms in the OBO doc.
    def initialize a, b, terms
      raise(ArgumentError, "nil arguments") if a.nil? || b.nil?
      @source, @target, @terms = a, b, terms
    end

    def to_s
      ["(#{@source}[#{@terms[@source].id.value}]", relationships.join(','), "#{@target}[#{@terms[@target].id.value}])"].join('-')
    end

    # Get the source term (as opposed to the +source+). Note that +source+ returns the line number.
    def source_term;  @terms[@source]; end

    # Get the target term (as opposed to the +target+). Note that +target+ returns the line number.
    def target_term;  @terms[@target]; end

    # Give relationships between the OBO terms that make up this edge. Typically there is only one; if you're sure there
    # is only one, use relationship.
    def relationships
      r = []
      source_term.relationships.each do |rel|
        r << rel.first if rel.last == target_term.id.value
      end
      target_term.relationships.each do |rel|
        r << "~#{rel.first}" if rel.last == source_term.id.value
      end
      r
    end

    # Find the relationship that forms this edge. If there are multiple, no guarantee that the 'right' one will be
    # returned.
    def relationship
      STDERR.puts("Warning: Multiple relationships detected for #{self.inspect}; returning first") if relationships.size > 1
      relationships.first
    end
    
  end
end

# Directed adjacency graph of OBO terms, based on RGL's DirectedAdjacencyGraph class.
#
# Ideally, should respond to all of the methods RGL::DirectedAdjacencyGraph responds to, but these have not all been
# implemented.
#
# Also, under the OBO definition, some terms may have multiple vertices, so methods are not directly analogous. For
# example, add_edge for two GO terms adds count(u)*count(v) edges, where count(x) is the number of stanzas for term x.
#
# Parse the Arabidopsis GO SLIM ontology:
#   o               =  parse_obo_file(File.read("goslim_plant.obo"))
#
# Create graphs for different types of relationships
#   graph           = {}
#   graph[:is_a]    =  OboParser::Graph.new(o, :is_a)
#   graph[:part_of] =  OboParser::Graph.new(o, :part_of)
#
# Combine the graphs
#   graph[:all]     =  OboParser::Graph.new(o, :regulates, Set, graph[:is_a], graph[:part_of])
#
# Print out a table of source terms, target terms, and relationships between them, one relationship per line.
#   graph.edges.each do |edge|
#     edge.relationships.each do |rel|
#       puts [edge.source_term.id.value, edge.target_term.id.value, rel].join("\t")
#     end
#   end
#
class OboParser::Graph < ::RGL::DirectedAdjacencyGraph
  def initialize obo, rtype = :is_a, edgelist_class = Set, *other_graphs
    rtype              = rtype.to_s
    @terms             = obo.terms
    term_id_to_indices = OboParser::Graph.hash_indices_by_term_id obo.terms
    edges              = []
    count              = 0

    super edgelist_class, *other_graphs

    # Build edge list.
    @terms.each do |term|
      term.relationships.each do |rel|
        if rel.first == rtype
          hash_indices_by_term_id[rel.last].each do |term_index|
            add_edge count, term_index
          end
        end
      end
      count += 1
    end
  end

  
  # Add edges from each term with ID u to each term with ID v.
  def add_edges_by_terms(u, v)
    hash_indices_by_term_id[u].each do |u_index|
      hash_indices_by_term_id[v].each do |v_index|
        add_edge(u_index, v_index)
      end
    end
  end


  # Returns an array of edges of the directed graph, but modified to include data on the terms that make up the nodes.
  def edges
    result = []
    c = edge_class
    each_edge { |u,v| result << c.new(u,v,@terms) }
    result
  end
  

  attr_reader :terms

protected

  # Hash from the term ID to the index in the term array
  def hash_indices_by_term_id #:nodoc:
    @hash_indices_by_term_id ||= OboParser::Graph.hash_indices_by_term_id @terms
  end

  class << self
    # A given term value may appear as the primary in a number of terms. This function returns a hash of term values to
    # term indices (index being where it appears in OboParser's +terms+ array).
    def hash_indices_by_term_id obo_terms
      count = 0 # position in terms list
      h     = Hash.new { |h,k| h[k] = [] }
      obo_terms.each do |term|
        h[term.id.value] << count
        count += 1
      end
      h
    end
  end

end
