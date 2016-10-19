<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes" encoding="UTF-8"/>

  <!-- If a field represents a qualified year range, attempt to split it into
       'start' and 'end' fields with a potential 'qualifier'. Uses some pretty
       lazy splitting; we can make this more complex later if additional use
       cases are provided. The current format is "qualifier yyyy(-yyyy)", e.g.,
       "circa 2001" or "between 1992-1997". -->
  <xsl:template name="qualified_date_range">
    <xsl:param name="prefix"/>
    <xsl:param name="suffix"/>
    <xsl:param name="value"/>
    <xsl:call-template name="general_mods_field">
      <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_testthing_')"/>
      <xsl:with-param name="suffix" select="$suffix"/>
      <xsl:with-param name="value">Whatever Goes Here</xsl:with-param>
    </xsl:call-template>
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
      <xsl:call-template name="general_mods_field">
        <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_parsed_qualifier_')"/>
        <xsl:with-param name="suffix" select="$suffix"/>
        <xsl:with-param name="value" select="$qualifier"/>
      </xsl:call-template>

      <!-- Attempt to parse a year range after the qualifier. -->
      <xsl:variable name="date_portion" select="substring-after($normalized_value, '_')"/>
      <xsl:variable name="low_end">
        <xsl:choose>
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
        <xsl:call-template name="general_mods_field">
          <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_qualified_range_low_end_')"/>
          <xsl:with-param name="suffix" select="$suffix"/>
          <xsl:with-param name="value" select="$low_end"/>
        </xsl:call-template>
        <xsl:call-template name="general_mods_field">
          <xsl:with-param name="prefix" select="concat($prefix, local-name(), '_qualified_range_high_end_')"/>
          <xsl:with-param name="suffix" select="$suffix"/>
          <xsl:with-param name="value" select="$high_end"/>
        </xsl:call-template>
      </xsl:if>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
