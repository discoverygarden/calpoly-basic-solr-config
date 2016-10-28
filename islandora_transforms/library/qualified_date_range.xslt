<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:date="http://exslt.org/dates-and-times"
        extension-element-prefixes="date">

  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <!-- If a field represents a qualified year range, attempt to turn it into a
       multivalued field representing the entire range. Uses some pretty lazy
       checks; the current format is "qualifier yyyy(-yyyy)", e.g.,"circa 2001"
       or "between 1992-1997". Intended to mimic the functionality of Solr range
       fields in Solr < 5.0. -->
  <xsl:template name="qualified_date_range">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <!-- This is extremely case-dependent and should be set based on what the
         facet low-end will be set to in Solr queries. -->
    <xsl:param name="range_bottom"/>
    <xsl:variable name="lowercase" select="'abcdefghijklmnopqrstuvwxyz_'"/>
    <xsl:variable name="uppercase" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ '"/>
    <xsl:variable name="nums" select="1234567890"/>
    <!-- Normalize space and case. -->
    <xsl:variable name="normalized_value" select="translate($value, $uppercase, $lowercase)"/>

    <!-- Grab the qualifier and create a field. -->
    <xsl:variable name="qualifier">
      <xsl:choose>
        <xsl:when test="contains($normalized_value, 'circa')">circa</xsl:when>
        <xsl:when test="contains($normalized_value, 'between')">between</xsl:when>
        <xsl:when test="contains($normalized_value, 'before')">before</xsl:when>
        <xsl:when test="contains($normalized_value, 'after')">after</xsl:when>
        <xsl:otherwise></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:if test="$qualifier != ''">
      <field>
        <xsl:attribute name="name">
          <xsl:value-of select="concat($prefix, local-name(), '_parsed_qualifier_', $suffix)"/>
        </xsl:attribute>
        <xsl:value-of select="$qualifier"/>
      </field>

      <!-- Attempt to parse a year range after the qualifier. -->
      <xsl:variable name="date_portion" select="substring-after($normalized_value, '_')"/>
      <xsl:variable name="low_end">
        <xsl:choose>
          <!-- Dates qualified with "before". -->
          <xsl:when test="$qualifier = 'before'">
            <xsl:value-of select="$range_bottom"/>
          </xsl:when>
          <!-- Single-valued dates. Will stop working in 10,000 AD, though we'll
               likely be in a Mad Max dustbowl scenario by then and have more
               pressing concerns than parsing qualified date ranges. -->
          <xsl:when test="string-length(translate($date_portion, $nums, '')) = 0 and string-length($date_portion) &lt;= 4">
            <xsl:value-of select="$date_portion"/>
          </xsl:when>
          <!-- Date ranges delimited by a dash. Similarly susceptible to various
          apocalyptic scenarios. -->
          <xsl:when test="string-length($date_portion) - string-length(translate($date_portion, '-', '')) = 1 and string-length(translate(substring-before($date_portion, '-'), $nums, '')) = 0 and string-length(substring-before($date_portion, '-')) &lt;= 4">
            <xsl:value-of select="substring-before($date_portion, '-')"/>
          </xsl:when>
          <!-- Otherwise is not real. -->
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <xsl:variable name="high_end">
        <xsl:choose>
          <!-- Dates with qualifier "after". -->
          <!-- XXX: Qualified "after" dates don't always make sense in context;
               for example, "created after 1992" is a meaningless statement that
               would be better written as "created between 1992-now", whereas
               "published after 1992" could be quite meaningful. This implements
               the ability to parse "after" dates with no other checks for
               meaningfulness - in short, if "after" doesn't make sense for one
               of your date fields and you write "after" in a doc for it, don't
               be surprised if you get nonsensical search results. -->
          <xsl:when test="$qualifier = 'after'">
            <xsl:value-of select="date:year(date:date-time())"/>
          </xsl:when>
          <!-- Single-valued dates. -->
          <xsl:when test="number($date_portion) = $date_portion and string-length($date_portion) &lt;= 4">
            <xsl:value-of select="$date_portion"/>
          </xsl:when>
          <!-- Date ranges delimited by a dash. -->
          <xsl:when test="string-length($date_portion) - string-length(translate($date_portion, '-', '')) = 1 and string-length(translate(substring-after($date_portion, '-'), $nums, '')) = 0 and string-length(substring-after($date_portion, '-')) &lt;= 4">
            <xsl:value-of select="substring-after($date_portion, '-')"/>
          </xsl:when>
          <!-- Nothin'. -->
          <xsl:otherwise></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- If we managed to get a date range, make some fields. Single-valued
           dates count as a 'range' of one year. -->
      <xsl:if test="$low_end != '' and $high_end != ''">
        <xsl:call-template name="qdr_year_loop">
          <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_')"/>
          <xsl:with-param name="start" select="$low_end"/>
          <xsl:with-param name="end" select="$high_end"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

  <!-- Year-looping template. -->
  <!-- XXX: As selecting "x to y" isn't implemented until XSLT 2.0, and there's
       no such thing as a "while" or "for", a tail-recursive template has to be
       the solution here. Avoiding spamming the call stack to death by branching
       the recursion as we go down. -->
  <xsl:template name="qdr_year_loop">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix">mdt</xsl:param>
    <xsl:param name="start"/>
    <xsl:param name="end"/>

    <xsl:if test="not($start &gt; $end)">
      <xsl:choose>
        <xsl:when test="$start = $end">
          <field>
            <xsl:attribute name="name">
              <xsl:value-of select="concat($prefix, $suffix)"/>
            </xsl:attribute>
            <!-- Could use the gsearch extensions date formatter, but we're only
                 ever dealing with years currently. -->
            <xsl:value-of select="concat($start, '-01-01T00:00:00Z')"/>
          </field>
        </xsl:when>
        <xsl:otherwise>
          <!-- Down the rabbit hole. -->
          <xsl:variable name="middle" select="floor(($start + $end) div 2)"/>
          <xsl:call-template name="qdr_year_loop">
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
            <xsl:with-param name="start" select="$start"/>
            <xsl:with-param name="end" select="$middle"/>
          </xsl:call-template>
          <xsl:call-template name="qdr_year_loop">
            <xsl:with-param name="prefix" select="$prefix"/>
            <xsl:with-param name="suffix" select="$suffix"/>
            <xsl:with-param name="start" select="$middle + 1"/>
            <xsl:with-param name="end" select="$end"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
