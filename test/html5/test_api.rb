# coding: utf-8
# frozen_string_literal: true

require "helper"

class TestHtml5API < Nokogiri::TestCase
  def test_parse_convenience_methods
    html = "<!DOCTYPE html><p>hi"
    base = Nokogiri::HTML5::Document.parse(html)
    html5_parse = Nokogiri::HTML5.parse(html)
    html5 = Nokogiri::HTML5(html)
    str = base.to_html
    assert_equal(str, html5_parse.to_html)
    assert_equal(str, html5.to_html)
  end

  def test_fragment_convenience_methods
    frag = "<div><p>hi</div>"
    base = Nokogiri::HTML5::DocumentFragment.parse(frag)
    html5_fragment = Nokogiri::HTML5.fragment(frag)
    assert_equal(base.to_html, html5_fragment.to_html)
  end

  def test_url
    html = "<p>hi"
    url = "http://example.com"

    doc = Nokogiri::HTML5::Document.parse(html)
    assert_nil(doc.url)

    doc = Nokogiri::HTML5::Document.parse(html, nil)
    assert_nil(doc.url)

    doc = Nokogiri::HTML5::Document.parse(html, url)
    assert_equal(url, doc.url)

    doc = Nokogiri::HTML5::Document.parse(html, url, max_errors: 1)
    assert_equal(url, doc.errors[0].file)

    doc = Nokogiri::HTML5.parse(html, url, max_errors: 1)
    assert_equal(url, doc.errors[0].file)

    doc = Nokogiri::HTML5(html, url, max_errors: 1)
    assert_equal(url, doc.errors[0].file)
  end

  def test_parse_encoding
    utf8 = "<!DOCTYPE html><body><p>おはようございます"
    shift_jis = utf8.encode(Encoding::SHIFT_JIS)
    raw = shift_jis.dup
    raw.force_encoding(Encoding::ASCII_8BIT)

    assert_match(/おはようございます/, Nokogiri::HTML5(utf8).to_s)
    assert_match(/おはようございます/, Nokogiri::HTML5(shift_jis).to_s)
    refute_match(/おはようございます/, Nokogiri::HTML5(raw).to_s)

    assert_match(/おはようございます/, Nokogiri::HTML5(raw, nil, Encoding::SHIFT_JIS).to_s)
    assert_match(/おはようございます/, Nokogiri::HTML5.parse(raw, nil, Encoding::SHIFT_JIS).to_s)
    assert_match(/おはようございます/, Nokogiri::HTML5::Document.parse(raw, nil, Encoding::SHIFT_JIS).to_s)
  end

  def test_fragment_encoding
    utf8 = "<div><p>おはようございます</div>"
    shift_jis = utf8.encode(Encoding::SHIFT_JIS)
    raw = shift_jis.dup
    raw.force_encoding(Encoding::ASCII_8BIT)

    assert_match(/おはようございます/, Nokogiri::HTML5.fragment(utf8).to_s)
    assert_match(/おはようございます/, Nokogiri::HTML5.fragment(shift_jis).to_s)
    refute_match(/おはようございます/, Nokogiri::HTML5.fragment(raw).to_s)

    assert_match(/おはようございます/, Nokogiri::HTML5.fragment(raw, Encoding::SHIFT_JIS).to_s)
    assert_match(/おはようございます/, Nokogiri::HTML5::DocumentFragment.parse(raw, Encoding::SHIFT_JIS).to_s)
  end

  def test_fragment_serialization_encoding
    frag = Nokogiri::HTML5.fragment("<span>아는 길도 물어가라</span>")
    html = frag.serialize(encoding: "US-ASCII")
    assert_equal("<span>&#xc544;&#xb294; &#xae38;&#xb3c4; &#xbb3c;&#xc5b4;&#xac00;&#xb77c;</span>", html)
    frag = Nokogiri::HTML5.fragment(html)
    assert_equal("<span>아는 길도 물어가라</span>", frag.serialize)
  end

  def test_serialization_encoding
    html = "<!DOCUMENT html><span>ฉันไม่พูดภาษาไทย</span>"
    doc = Nokogiri::HTML5(html)
    span = doc.at("/html/body/span")
    serialized = span.inner_html(encoding: "US-ASCII")
    assert_match(/^(?:&#(?:\d+|x\h+);)*$/, serialized)
    assert_equal("ฉันไม่พูดภาษาไทย".each_char.map(&:ord),
      serialized.scan(/&#(\d+|x\h+);/).map do |s|
        s = s.first
        if s.start_with?("x")
          s[1..-1].to_i(16)
        else
          s.to_i
        end
      end)

    doc2 = Nokogiri::HTML5(doc.serialize(encoding: "Big5"))
    html2 = doc2.serialize(encoding: "UTF-8")
    assert_match("ฉันไม่พูดภาษาไทย", html2)
  end

  ["pre", "listing", "textarea"].each do |tag|
    define_method("test_serialize_preserve_newline_#{tag}".to_sym) do
      doc = Nokogiri::HTML5("<!DOCTYPE html><#{tag}>\n\nContent</#{tag}>")
      html = doc.at("/html/body/#{tag}").serialize(preserve_newline: true)
      assert_equal "<#{tag}>\n\nContent</#{tag}>", html
    end

    define_method("test_inner_html_preserve_newline_#{tag}".to_sym) do
      doc = Nokogiri::HTML5("<!DOCTYPE html><#{tag}>\n\nContent</#{tag}>")
      html = doc.at("/html/body/#{tag}").inner_html(preserve_newline: true)
      assert_equal "\n\nContent", html
    end
  end

  def test_document_io
    html = StringIO.new("<!DOCTYPE html><span>test</span>", "r")
    doc = Nokogiri::HTML5::Document.read_io(html)
    refute_nil(doc.at_xpath("/html/body/span"))
  end

  def test_document_memory
    html = "<!DOCTYPE html><span>test</span>"
    doc = Nokogiri::HTML5::Document.read_memory(html)
    refute_nil(doc)
    refute_nil(doc.at_xpath("/html/body/span"))
  end

  def test_document_io_failure
    html = "<!DOCTYPE html><span>test</span>"
    assert_raises(ArgumentError) { Nokogiri::HTML5::Document.read_io(html) }
  end

  def test_document_memory_failure
    html = StringIO.new("<!DOCTYPE html><span>test</span>", "r")
    assert_raises(ArgumentError) { Nokogiri::HTML5::Document.read_memory(html) }
  end

  def test_document_parse_failure
    html = ["Neither a string, nor I/O"]
    assert_raises(ArgumentError) { Nokogiri::HTML5::Document.parse(html) }
  end

  def test_ownership
    # Test that we don't change the passed in string, even if we need to
    # re-encode it.
    html = "<!DOCTYPE html><html></html>"
    refute_nil(Nokogiri::HTML5.parse(html))

    iso8859_1 = html.encode(Encoding::ISO_8859_1).freeze
    refute_nil(Nokogiri::HTML5.parse(iso8859_1))

    ascii_8bit = html.encode(Encoding::ASCII_8BIT).freeze
    refute_nil(Nokogiri::HTML5.parse(ascii_8bit))
  end

  def test_fragment_from_node
    doc = Nokogiri.HTML5("<!DOCTYPE html><form><span></span></form>")
    span = doc.at_xpath("/html/body/form/span")
    refute_nil(span)
    frag = span.fragment("<form>Nested forms should be ignored</form>")
    assert(frag.is_a?(Nokogiri::HTML5::DocumentFragment))
    assert_equal(1, frag.children.length)
    nested_form = frag.at_xpath("form")
    assert_nil(nested_form)
    assert_predicate(frag.children[0], :text?)
  end

  def test_fragment_from_node_no_form
    doc = Nokogiri.HTML5("<!DOCTYPE html><span></span></form>")
    span = doc.at_xpath("/html/body/span")
    refute_nil(span)
    frag = span.fragment("<form><span>Form should not be ignored</span></form>")
    assert(frag.is_a?(Nokogiri::HTML5::DocumentFragment))
    assert_equal(1, frag.children.length)
    form = frag.at_xpath("form")
    refute_nil(form)
  end

  def test_empty_fragment
    doc = Nokogiri.HTML5("<!DOCTYPE html><body>")
    frag = doc.fragment
    assert(frag.is_a?(Nokogiri::HTML5::DocumentFragment))
    assert_empty(frag.children)
  end

  def test_fragment_with_annotation_xml_context
    # An annotation-xml element with an encoding of text/html or application/xhtml+xml
    # is an HTML integration point so its children are not in the MathML namespace.
    # Other encodings are not HTML integration points so children are in the MathML namespace.
    doc = Nokogiri.HTML5("<!DOCTYPE html><math><annotation-xml encoding='MathML-Presentation' /></math>")
    a_xml = doc.xpath("//math:annotation-xml")[0]
    frag = a_xml.fragment("<mi>x</mi>")
    mi = frag.children[0]
    assert_equal("mi", mi.name)
    refute_nil(mi.namespace)
    assert_equal("math", mi.namespace.prefix)

    doc = Nokogiri.HTML5("<!DOCTYPE html><math><annotation-xml encoding='text/html' /></math>")
    a_xml = doc.xpath("//math:annotation-xml")[0]
    frag = a_xml.fragment("<mi>x</mi>")
    mi = frag.children[0]
    assert_equal("mi", mi.name)
    assert_nil(mi.namespace)
  end

  def test_html_eh
    doc = Nokogiri.HTML5("<html><body><div></div></body></html>")
    assert_predicate(doc, :html?)
    refute_predicate(doc, :xml?)
  end

  def test_node_wrap
    doc = Nokogiri.HTML5("<html><body><div></div></body></html>")
    div = doc.at_css("div")
    div.wrap("<section></section>")

    assert_equal("section", div.parent.name)
    assert_equal("body", div.parent.parent.name)
  end

  def test_node_wrap_uses_parent_node_as_parsing_context_node
    doc = Nokogiri.HTML5("<html><body><select><option></option></select></body></html>")
    el = doc.at_css("option")

    # fails to parse because `div` is not valid in the context of a `select` element
    exception = assert_raises(RuntimeError) { el.wrap("<div></div>") }
    assert_match(/Failed to parse .* in the context of a 'select' element/, exception.message)

    # parses because `optgroup` is valid in the context of a `select` element
    el.wrap("<optgroup></optgroup>")
    assert_equal("optgroup", el.parent.name)
    assert_equal("select", el.parent.parent.name)
  end

  describe Nokogiri::HTML5::Document do
    describe "#fragment" do
      it "parses text nodes in a `body` context" do
        doc = Nokogiri.HTML5("x")
        frag = doc.fragment("z")
        assert_equal("z", frag.to_s)
      end

      it "drops tags that are not appropriate in a `body` context" do
        doc = Nokogiri.HTML5("x")
        frag = doc.fragment("<head></head>")
        assert_empty(frag.children)
      end
    end

    describe "subclassing" do
      let(:klass) do
        Class.new(Nokogiri::HTML5::Document) do
          attr_accessor :initialized_with, :initialized_count

          def initialize(*args)
            super
            @initialized_with = args
            @initialized_count ||= 0
            @initialized_count += 1
          end
        end
      end

      describe ".new" do
        it "returns an instance of the expected class" do
          doc = klass.new
          assert_instance_of(klass, doc)
        end

        it "calls #initialize exactly once" do
          doc = klass.new
          assert_equal(1, doc.initialized_count)
        end

        it "passes arguments to #initialize" do
          doc = klass.new("http://www.w3.org/TR/REC-html40/loose.dtd", "-//W3C//DTD HTML 4.0 Transitional//EN")
          assert_equal(
            ["http://www.w3.org/TR/REC-html40/loose.dtd", "-//W3C//DTD HTML 4.0 Transitional//EN"],
            doc.initialized_with
          )
        end
      end

      it "#dup returns the expected class" do
        doc = klass.new.dup
        assert_instance_of(klass, doc)
      end

      describe ".parse" do
        let(:html) { Nokogiri::HTML5.parse(File.read(HTML_FILE)) }

        it "returns an instance of the expected class" do
          doc = klass.parse(File.read(HTML_FILE))
          assert_instance_of(klass, doc)
        end

        it "calls #initialize exactly once" do
          doc = klass.parse(File.read(HTML_FILE))
          assert_equal(1, doc.initialized_count)
        end

        it "parses the doc" do
          doc = klass.parse(File.read(HTML_FILE))
          assert_equal(html.root.to_s, doc.root.to_s)
        end
      end
    end
  end

  describe Nokogiri::HTML5::DocumentFragment do
    describe "subclassing" do
      let(:klass) do
        Class.new(Nokogiri::HTML5::DocumentFragment) do
          attr_accessor :initialized_with, :initialized_count

          def initialize(*args)
            super
            @initialized_with = args
            @initialized_count ||= 0
            @initialized_count += 1
          end
        end
      end
      let(:html) { Nokogiri::HTML5.parse(File.read(HTML_FILE), HTML_FILE) }

      describe ".new" do
        it "returns an instance of the right class" do
          fragment = klass.new(html, "<div>a</div>")
          assert_instance_of(klass, fragment)
        end

        it "calls #initialize exactly once" do
          fragment = klass.new(html, "<div>a</div>")
          assert_equal(1, fragment.initialized_count)
        end

        it "passes args to #initialize" do
          fragment = klass.new(html, "<div>a</div>")
          assert_equal([html, "<div>a</div>"], fragment.initialized_with)
        end
      end

      it "#dup returns the expected class" do
        doc = klass.new(html, "<div>a</div>").dup
        assert_instance_of(klass, doc)
      end

      describe ".parse" do
        it "returns an instance of the right class" do
          fragment = klass.parse("<div>a</div>")
          assert_instance_of(klass, fragment)
        end

        it "calls #initialize exactly once" do
          fragment = klass.parse("<div>a</div>")
          assert_equal(1, fragment.initialized_count)
        end

        it "passes the fragment" do
          fragment = klass.parse("<div>a</div>")
          assert_equal(Nokogiri::HTML5::DocumentFragment.parse("<div>a</div>").to_s, fragment.to_s)
        end
      end
    end
  end
end if Nokogiri.uses_gumbo?
