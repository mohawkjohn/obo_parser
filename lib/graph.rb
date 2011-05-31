require 'rubygems'
require 'rgl/adjacency'

# Graph of OBO terms.
#
# Ideally, should respond to all of the methods RGL::DirectedAdjacencyGraph responds to, but these have not all been
# implemented.
#
# Also, under the OBO definition, some terms may have multiple vertices, so methods are not directly analogous. For
# example, add_edge for two GO terms adds count(u)*count(v) edges, where count(x) is the number of stanzas for term x.
class OboParser::Graph < ::RGL::DirectedAdjacencyGraph
  def initialize obo, rtype = :is_a, edgelist_class = Set, *other_graphs
    @relationship_type = rtype.to_s
    @terms             = obo.terms
    term_id_to_indices = OboParser::Graph.hash_indices_by_term_id obo.terms
    edges              = []
    count              = 0

    super edgelist_class, *other_graphs

    # Build edge list.
    @terms.each do |term|
      term.relationships.each do |rel|
        if rel.first == @relationship_type
          hash_indices_by_term_id[rel.last].each do |term_index|
            add_edge term_index, count
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

  
  def inspect #:nodoc:
    "#{@relationship_type.to_sym.inspect} #{super}"
  end
  

  attr_reader :relationship_type, :terms

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