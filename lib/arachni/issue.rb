=begin
    Copyright 2010-2012 Tasos Laskos <tasos.laskos@gmail.com>

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
=end

module Arachni

#
# Represents a detected issues.
#
# @author Tasos "Zapotek" Laskos
#                                      <tasos.laskos@gmail.com>
#
class Issue

    #
    # Holds constants to describe the {Issue#severity} of a
    # vulnerability.
    #
    module Severity
        HIGH          = 'High'
        MEDIUM        = 'Medium'
        LOW           = 'Low'
        INFORMATIONAL = 'Informational'
    end

    #
    # Holds constants to describe the {Issue#elem} of a
    # vulnerability.
    #
    module Element
        LINK    = 'link'
        FORM    = 'form'
        COOKIE  = 'cookie'
        HEADER  = 'header'
        BODY    = 'body'
        PATH    = 'path'
        SERVER  = 'server'
    end

    #
    # The name of the issue
    #
    # @return    [String]
    #
    attr_accessor :name

    #
    # The module that detected the issue
    #
    # @return    [String]    the name of the module
    #
    attr_accessor :mod_name

    #
    # The vulnerable HTTP variable
    #
    # @return    [String]    the name of the http variable
    #
    attr_accessor :var

    #
    # The vulnerable URL
    #
    # @return    [String]
    #
    attr_accessor :url

    #
    # The headers exchanged during the attack
    #
    # @return [Hash<String, Hash>]  request and reply headers
    #
    attr_accessor :headers

    #
    # The HTML response of the attack
    #
    # @return [String]  the html response of the attack
    #
    attr_accessor :response

    #
    # The injected data that revealed the issue
    #
    # @return    [String]
    #
    attr_accessor :injected

    #
    # The string that identified the issue
    #
    # @return    [String]
    #
    attr_accessor :id

    #
    # The regexp that identified the issue
    #
    # @return    [String]
    #
    attr_reader   :regexp

    #
    # The data that was matched by the regexp
    #
    # @return    [String]
    #
    attr_accessor :regexp_match

    #
    # The vulnerable element, link, form or cookie
    #
    # @return    [String]
    #
    attr_accessor :elem

    #
    # HTTP method
    #
    # @return    [String]
    #
    attr_accessor :method

    #
    # The description of the issue
    #
    # @return    [String]
    #
    attr_accessor :description

    #
    # References related to the issue
    #
    # @return    [Hash]
    #
    attr_accessor :references

    #
    # The CWE ID number of the issue
    #
    # @return    [String]
    #
    attr_accessor :cwe

    #
    # The CWE URL of the issue
    #
    # @return    [String]
    #
    attr_accessor :cwe_url

    #
    # To be assigned a constant form {Severity}
    #
    # @see Severity
    #
    # @return    [String]
    #
    attr_accessor :severity

    #
    # The CVSS v2 score
    #
    # @return    [String]
    #
    attr_accessor :cvssv2

    #
    # A brief text informing the user how to remedy the situation
    #
    # @return    [String]
    #
    attr_accessor :remedy_guidance

    #
    # A code snippet showing the user how to remedy the situation
    #
    # @return    [String]
    #
    attr_accessor :remedy_code

    #
    # Placeholder variable to be populated by {AuditStore#prepare_variations}
    #
    # @see AuditStore#prepare_variations
    #
    attr_accessor :variations

    #
    # Is manual verification required?
    #
    # @return  [Bool]
    #
    attr_accessor :verification

    #
    # The Metasploit module that can exploit the vulnerability.
    #
    # ex. exploit/unix/webapp/php_include
    #
    # @return  [String]
    #
    attr_accessor :metasploitable

    attr_reader   :opts

    attr_accessor :internal_modname
    attr_accessor :tags
    attr_accessor :_hash

    #
    # Sets up the instance attributes
    #
    # @param    [Hash]    opts  configuration hash
    #                     Usually the returned data of a module's
    #                     info() method for the references
    #                     merged with a name=>value pair hash holding
    #                     class attributes
    #
    def initialize( opts = {} )
        @verification = false

        opts.each {
            |k, v|
            begin
                send( "#{k.to_s.downcase}=", encode( v ) )
            rescue Exception => e
            end
        }

        opts[:issue].each {
            |k, v|
            begin
                send( "#{k.to_s.downcase}=", encode( v ) )
            rescue Exception => e
            end
        } if opts[:issue]

        if opts[:headers] && opts[:headers][:request]
            @headers[:request] = {}.merge( opts[:headers][:request] )
        end

        if opts[:headers] && opts[:headers][:response].is_a?( Hash )
            @headers[:response] = {}.merge( opts[:headers][:response] )
        end

        if @cwe
            @cwe_url = "http://cwe.mitre.org/data/definitions/" + @cwe + ".html"
        end

        @mod_name   = opts[:name]
        @references = opts[:references] || {}
    end

    def regexp=( regexp )
        return if !regexp
        @regexp = regexp.to_s
    end

    def opts=( hash )
        return if !hash
        hash[:regexp] = hash[:regexp].to_s
        hash[:match]  ||= false
        @opts = hash.dup
    end

    def []( k )
        instance_variable_get( "@#{k.to_s}".to_sym )
    end

    def []=( k, v )
        v= encode( v )
        begin
            send( "#{k.to_s}=", v )
        rescue
            instance_variable_set( "@#{k.to_s}".to_sym, v )
        end
    end

    def to_h
        h = {}
        each_pair {
            |k, v|
            h[k] = v
        }
        h
    end

    def each
        self.instance_variables.each {
            |var|
            yield( { normalize_name( var ) => instance_variable_get( var ) } )
        }
    end

    def each_pair
        self.instance_variables.each {
            |var|
            yield normalize_name( var ), instance_variable_get( var )
        }
    end

    def remove_instance_var( var )
        remove_instance_variable( var )
    end

    private

    def encode( str )
        return str if !str || !str.is_a?( String )
        str.encode( 'UTF-8', :invalid => :replace, :undef => :replace )
    end

    def normalize_name( name )
        name.to_s.gsub( /@/, '' )
    end

end
end
