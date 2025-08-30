<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0"
  exclude-result-prefixes="tt">

  <xsl:output method="text" encoding="UTF-8"/>

  <!-- LF newlines; use select= to avoid whitespace stripping in .NET -->
  <xsl:variable name="NL" select="'&#x0A;'"/>
  <xsl:variable name="IND" select="'  '"/> <!-- 2-space indent for nested lists -->

  <!-- Optional: filter to a specific fixture title (exact match) -->
  <xsl:param name="fixture" select="''"/>

  <!-- Join parameters into foo, "bar" -->
  <xsl:template name="join-params">
    <xsl:param name="ctx"/>
    <xsl:for-each select="$ctx/tt:param">
      <xsl:if test="position() &gt; 1">, </xsl:if>
      <xsl:variable name="typ" select="normalize-space(tt:type)"/>
      <xsl:variable name="c"   select="normalize-space(tt:value/tt:const)"/>
      <xsl:choose>
        <xsl:when test="$typ='String'">"<xsl:value-of select="$c"/>"</xsl:when>
        <xsl:otherwise><xsl:value-of select="$c"/></xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
  </xsl:template>

  <!-- Root -->
  <xsl:template match="/">
    <xsl:text># Test Listing</xsl:text><xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>

    <xsl:choose>
      <xsl:when test="normalize-space($fixture)!=''">
        <xsl:apply-templates select="//tt:tf[normalize-space(tt:title)=normalize-space($fixture)]"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:apply-templates select="//tt:tt/tt:tf"/>
      </xsl:otherwise>
    </xsl:choose>

    <!-- Only show global definitions when not filtering -->
    <xsl:if test="normalize-space($fixture)='' and //tt:tc_definitions/tt:tc_definition">
      <xsl:value-of select="$NL"/>
      <xsl:text>## Test Case Definitions</xsl:text><xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>
      <xsl:apply-templates select="//tt:tc_definitions/tt:tc_definition"/>
    </xsl:if>
  </xsl:template>

  <!-- Fixture -->
  <xsl:template match="tt:tf">
    <xsl:text>## Fixture: </xsl:text><xsl:value-of select="normalize-space(tt:title)"/><xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:preparation"/>
    <xsl:apply-templates select="tt:ts"/>
    <xsl:apply-templates select="tt:tc"/>
    <xsl:apply-templates select="tt:tf"/>
    <xsl:apply-templates select="tt:completion"/>
    <xsl:value-of select="$NL"/>
  </xsl:template>

  <!-- Preparation / Completion (standalone in fixture) -->
  <xsl:template match="tt:preparation | tt:completion">
    <xsl:text>### </xsl:text>
    <xsl:choose>
      <xsl:when test="self::tt:preparation"><xsl:text>Preparation</xsl:text></xsl:when>
      <xsl:otherwise><xsl:text>Completion</xsl:text></xsl:otherwise>
    </xsl:choose>
    <xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="''"/>
    </xsl:apply-templates>
    <xsl:value-of select="$NL"/>
  </xsl:template>

  <!-- Test sequence -->
  <xsl:template match="tt:ts">
    <xsl:text>### Test Sequence</xsl:text><xsl:value-of select="$NL"/>
    <xsl:if test="normalize-space(tt:title)!=''">
      <xsl:value-of select="normalize-space(tt:title)"/><xsl:value-of select="$NL"/>
    </xsl:if>
    <xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:tttestcase"/>
  </xsl:template>

  <!-- Sequence item: resolve by ID, else by name (tc:title or tc_definition:name), then inline -->
  <xsl:template match="tt:tttestcase">
    <xsl:variable name="id"   select="normalize-space(tt:tcid)"/>
    <xsl:variable name="name" select="normalize-space(tt:name)"/>

    <xsl:variable name="byId"
      select="(//tt:tc[normalize-space(tt:tcid)=$id] |
               //tt:tc_definition[normalize-space(tt:tcid)=$id])[1]"/>
    <xsl:variable name="byName"
      select="(//tt:tc[normalize-space(tt:title)=$name] |
               //tt:tc_definition[normalize-space(tt:name)=$name])[1]"/>

    <!-- Bullet for the referenced test -->
    <xsl:text>- `</xsl:text><xsl:value-of select="$name"/><xsl:text>`</xsl:text>
    <xsl:if test="$id!=''"><xsl:text> [</xsl:text><xsl:value-of select="$id"/><xsl:text>]</xsl:text></xsl:if>
    <xsl:value-of select="$NL"/>

    <!-- Inline the body as nested bullets -->
    <xsl:choose>
      <xsl:when test="$byId">
        <xsl:apply-templates select="$byId" mode="inline-md"/>
      </xsl:when>
      <xsl:when test="$byName">
        <xsl:text>  - _matched by name_</xsl:text><xsl:value-of select="$NL"/>
        <xsl:apply-templates select="$byName" mode="inline-md"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>  - _definition not found_</xsl:text><xsl:value-of select="$NL"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Inline rendering of a TC/TC definition (nested under the sequence item) -->
  <xsl:template match="tt:tc | tt:tc_definition" mode="inline-md">
    <xsl:if test="tt:preparation">
      <xsl:text>  - **Preparation**</xsl:text><xsl:value-of select="$NL"/>
      <xsl:apply-templates select="tt:preparation/tt:*" mode="step-md">
        <xsl:with-param name="indent" select="concat($IND,$IND)"/> <!-- 4 spaces -->
      </xsl:apply-templates>
    </xsl:if>

    <xsl:if test="tt:*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]">
      <xsl:text>  - **Steps**</xsl:text><xsl:value-of select="$NL"/>
      <xsl:apply-templates select="tt:*[
        not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or
            self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)
      ]" mode="step-md">
        <xsl:with-param name="indent" select="concat($IND,$IND)"/>
      </xsl:apply-templates>
    </xsl:if>

    <xsl:if test="tt:completion">
      <xsl:text>  - **Completion**</xsl:text><xsl:value-of select="$NL"/>
      <xsl:apply-templates select="tt:completion/tt:*" mode="step-md">
        <xsl:with-param name="indent" select="concat($IND,$IND)"/>
      </xsl:apply-templates>
    </xsl:if>
  </xsl:template>

  <!-- Standalone test cases / definitions (only used when not filtering) -->
  <xsl:template match="tt:tc | tt:tc_definition">
    <xsl:variable name="title" select="normalize-space(tt:title)"/>
    <xsl:variable name="name"  select="normalize-space(tt:name)"/>
    <xsl:variable name="id"    select="normalize-space(tt:tcid)"/>

    <xsl:text>### </xsl:text>
    <xsl:choose>
      <xsl:when test="self::tt:tc_definition"><xsl:text>TC Definition: </xsl:text><xsl:value-of select="$name"/></xsl:when>
      <xsl:otherwise><xsl:text>TestCase: </xsl:text><xsl:value-of select="$title"/></xsl:otherwise>
    </xsl:choose>
    <xsl:if test="$id!=''"><xsl:text> `[</xsl:text><xsl:value-of select="$id"/><xsl:text>]`</xsl:text></xsl:if>
    <xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>

    <xsl:apply-templates select="tt:preparation"/>
    <xsl:if test="tt:*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]">
      <xsl:text>#### Steps</xsl:text><xsl:value-of select="$NL"/><xsl:value-of select="$NL"/>
      <xsl:apply-templates select="tt:*[
        not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or
            self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)
      ]" mode="step-md">
        <xsl:with-param name="indent" select="''"/>
      </xsl:apply-templates>
      <xsl:value-of select="$NL"/>
    </xsl:if>
    <xsl:apply-templates select="tt:completion"/>
  </xsl:template>

  <!-- ===== Step renderers (Markdown, nested lists) ===== -->
  <xsl:template match="tt:ttfunction" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `TTFUNC </xsl:text><xsl:value-of select="tt:name"/><xsl:text>(</xsl:text>
    <xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>
    <xsl:text>)`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:caplfunction" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `CAPL </xsl:text><xsl:value-of select="tt:name"/><xsl:text>(</xsl:text>
    <xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>
    <xsl:text>)`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:netfunction" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `NET </xsl:text><xsl:value-of select="tt:class"/><xsl:text>.</xsl:text><xsl:value-of select="tt:name"/><xsl:text>(</xsl:text>
    <xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>
    <xsl:text>)`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:wait" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `WAIT </xsl:text>
    <xsl:value-of select="normalize-space(tt:time/tt:value/tt:const)"/><xsl:text> </xsl:text>
    <xsl:value-of select="normalize-space(tt:time/tt:unit)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:set" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `SET </xsl:text>
    <xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:sink/tt:dbobject)"/>
    <xsl:text> = </xsl:text>
    <xsl:choose>
      <xsl:when test="tt:in/tt:assignment/tt:source/tt:valuetable_entry">
        <xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:source/tt:valuetable_entry)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:source/tt:value/tt:const)"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:awaitvaluematch" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `AWAITVALUEMATCH timeout=</xsl:text>
    <xsl:value-of select="normalize-space(tt:timeout/tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    <xsl:for-each select="tt:compare">
      <xsl:value-of select="concat($indent,$IND)"/><xsl:text>- `</xsl:text><xsl:value-of select="normalize-space(tt:dbobject)"/><xsl:text> == </xsl:text><xsl:value-of select="normalize-space(tt:eq/tt:const)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    </xsl:for-each>
  </xsl:template>

  <xsl:template match="tt:diagservice" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `DIAG </xsl:text>
    <xsl:value-of select="normalize-space(tt:service)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:for" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **FOR** `</xsl:text><xsl:value-of select="normalize-space(tt:loopvar)"/>
    <xsl:text> from </xsl:text><xsl:value-of select="normalize-space(tt:startvalue/tt:const)"/>
    <xsl:text> to </xsl:text><xsl:value-of select="normalize-space(tt:stopvalue/tt:const)"/>
    <xsl:text> step </xsl:text><xsl:value-of select="normalize-space(tt:increment/tt:const)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*[
      not(self::tt:title or self::tt:loopvar or self::tt:loopvartype or
          self::tt:startvalue or self::tt:stopvalue or self::tt:increment)
    ]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:foreach" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **FOREACH** `</xsl:text><xsl:value-of select="normalize-space(tt:loopvar)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*[
      not(self::tt:title or self::tt:loopvar or self::tt:listparameter)
    ]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

 
  <!-- Composite: STATECHANGE -->
  <xsl:template match="tt:statechange" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="desc">
      <xsl:choose>
        <xsl:when test="normalize-space(tt:name)!=''"><xsl:value-of select="normalize-space(tt:name)"/></xsl:when>
        <xsl:when test="normalize-space(tt:state)!=''"><xsl:value-of select="normalize-space(tt:state)"/></xsl:when>
        <xsl:when test="normalize-space(tt:targetstate)!=''"><xsl:value-of select="normalize-space(tt:targetstate)"/></xsl:when>
        <xsl:when test="normalize-space(tt:target)!=''"><xsl:value-of select="normalize-space(tt:target)"/></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHANGE</xsl:text>
    <xsl:if test="normalize-space($desc)!=''"><xsl:text> </xsl:text><xsl:value-of select="$desc"/></xsl:if>
    <xsl:text>**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Composite: STATECHECK -->
  <xsl:template match="tt:statecheck" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHECK**</xsl:text>
    <xsl:if test="tt:timeout">
      <xsl:text> `timeout=</xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/><xsl:text>`</xsl:text>
    </xsl:if>
    <xsl:value-of select="$NL"/>
    <!-- comparisons -->
    <xsl:for-each select="tt:compare">
      <xsl:value-of select="concat($indent,$IND)"/><xsl:text>- `</xsl:text><xsl:value-of select="normalize-space(tt:dbobject)"/><xsl:text> == </xsl:text><xsl:value-of select="normalize-space(tt:eq/tt:const)"/><xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    </xsl:for-each>
    <!-- additional nested steps -->
    <xsl:apply-templates select="tt:*[not(self::tt:compare)]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Composite: VARIABLES -->
  <xsl:template match="tt:variables" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **VARIABLES**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- COMMENT with actual text -->
  <xsl:template match="tt:comment" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="txt">
      <xsl:choose>
        <xsl:when test="normalize-space(tt:text)!=''"><xsl:value-of select="normalize-space(tt:text)"/></xsl:when>
        <xsl:when test="normalize-space(tt:value/tt:const)!=''"><xsl:value-of select="normalize-space(tt:value/tt:const)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(.)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$indent"/><xsl:text>- _COMMENT_</xsl:text>
    <xsl:if test="$txt!=''"><xsl:text>: </xsl:text><xsl:value-of select="$txt"/></xsl:if>
    <xsl:value-of select="$NL"/>
  </xsl:template>

   <!-- ===== Composite steps (Markdown) ===== -->

  <!-- STATECHANGE -->
  <xsl:template match="tt:statechange" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="desc">
      <xsl:choose>
        <xsl:when test="normalize-space(tt:name)!=''"><xsl:value-of select="normalize-space(tt:name)"/></xsl:when>
        <xsl:when test="normalize-space(tt:state)!=''"><xsl:value-of select="normalize-space(tt:state)"/></xsl:when>
        <xsl:when test="normalize-space(tt:targetstate)!=''"><xsl:value-of select="normalize-space(tt:targetstate)"/></xsl:when>
        <xsl:when test="normalize-space(tt:target)!=''"><xsl:value-of select="normalize-space(tt:target)"/></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHANGE</xsl:text>
    <xsl:if test="normalize-space($desc)!=''"><xsl:text> </xsl:text><xsl:value-of select="$desc"/></xsl:if>
    <xsl:text>**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:title" mode="step-md">
  <xsl:param name="indent"/>
  <xsl:variable name="tNode"
    select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
  <xsl:variable name="t" select="normalize-space(string($tNode))"/>
  <xsl:value-of select="$indent"/><xsl:text>- _TITLE_</xsl:text>
  <xsl:if test="$t!=''"><xsl:text>: </xsl:text><xsl:value-of select="$t"/></xsl:if>
  <xsl:value-of select="$NL"/>
</xsl:template>


  <xsl:template match="tt:statechange/tt:in" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **IN**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:wait" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `WAIT </xsl:text>
    <xsl:choose>
      <xsl:when test="tt:time">
        <xsl:value-of select="normalize-space(tt:time/tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:time/tt:unit)"/>
      </xsl:when>
      <xsl:when test="tt:value">
        <xsl:value-of select="normalize-space(tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:unit)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="normalize-space(string(.))"/>
      </xsl:otherwise>
    </xsl:choose>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:expected" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **EXPECTED**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:for-each select=".//tt:compare">
      <xsl:value-of select="concat($indent,$IND,'- `',normalize-space(tt:dbobject),' == ',normalize-space(tt:eq/tt:const),'`',$NL)"/>
    </xsl:for-each>
    <xsl:apply-templates select="tt:*[not(self::tt:compare)]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- STATECHECK -->
  <xsl:template match="tt:statecheck" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHECK**</xsl:text>
    <xsl:if test="tt:timeout">
      <xsl:text> `timeout=</xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/><xsl:text>`</xsl:text>
    </xsl:if>
    <xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:title | tt:expected | tt:*[not(self::tt:title or self::tt:expected)]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statecheck/tt:title" mode="step-md">
  <xsl:param name="indent"/>
	  <xsl:variable name="tNode"
		select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
	  <xsl:variable name="t" select="normalize-space(string($tNode))"/>
	  <xsl:value-of select="$indent"/><xsl:text>- _TITLE_</xsl:text>
	  <xsl:if test="$t!=''"><xsl:text>: </xsl:text><xsl:value-of select="$t"/></xsl:if>
	  <xsl:value-of select="$NL"/>
	</xsl:template>


  <xsl:template match="tt:statecheck/tt:expected" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **EXPECTED**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:for-each select=".//tt:compare">
      <xsl:value-of select="concat($indent,$IND,'- `',normalize-space(tt:dbobject),' == ',normalize-space(tt:eq/tt:const),'`',$NL)"/>
    </xsl:for-each>
    <xsl:apply-templates select="tt:*[not(self::tt:compare)]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- VARIABLES -->
  <xsl:template match="tt:variables" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **VARIABLES**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:variables/tt:variable_definition" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="nm"  select="normalize-space(tt:name)"/>
    <xsl:variable name="val" select="normalize-space(tt:value/tt:const)"/>
    <xsl:value-of select="$indent"/><xsl:text>- `VARIABLE_DEFINITION</xsl:text>
    <xsl:if test="$nm!='' or $val!=''">
      <xsl:text> </xsl:text><xsl:value-of select="$nm"/><xsl:if test="$val!=''"><xsl:text> = </xsl:text><xsl:value-of select="$val"/></xsl:if>
    </xsl:if>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

 
   <!-- STATECHANGE -->
  <xsl:template match="tt:statechange" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="desc">
      <xsl:choose>
        <xsl:when test="normalize-space(tt:name)!=''"><xsl:value-of select="normalize-space(tt:name)"/></xsl:when>
        <xsl:when test="normalize-space(tt:state)!=''"><xsl:value-of select="normalize-space(tt:state)"/></xsl:when>
        <xsl:when test="normalize-space(tt:targetstate)!=''"><xsl:value-of select="normalize-space(tt:targetstate)"/></xsl:when>
        <xsl:when test="normalize-space(tt:target)!=''"><xsl:value-of select="normalize-space(tt:target)"/></xsl:when>
        <xsl:otherwise/>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHANGE</xsl:text>
    <xsl:if test="normalize-space($desc)!=''"><xsl:text> </xsl:text><xsl:value-of select="$desc"/></xsl:if>
    <xsl:text>**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:title" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="concat($indent,'- _TITLE_: ', normalize-space(string(.)), $NL)"/>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:in" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **IN**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:wait" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `WAIT </xsl:text>
    <xsl:choose>
      <xsl:when test="tt:time">
        <xsl:value-of select="normalize-space(tt:time/tt:value/tt:const)"/><xsl:text> </xsl:text>
        <xsl:value-of select="normalize-space(tt:time/tt:unit)"/>
      </xsl:when>
      <xsl:when test="tt:value">
        <xsl:value-of select="normalize-space(tt:value/tt:const)"/><xsl:text> </xsl:text>
        <xsl:value-of select="normalize-space(tt:unit)"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="normalize-space(string(.))"/></xsl:otherwise>
    </xsl:choose>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:expected" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **EXPECTED**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- STATECHECK -->
  <xsl:template match="tt:statecheck" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **STATECHECK**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:statecheck/tt:title" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="concat($indent,'- _TITLE_: ', normalize-space(string(.)), $NL)"/>
  </xsl:template>

  <xsl:template match="tt:statecheck/tt:expected" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **EXPECTED**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Comparisons -->
  <!-- Comparisons (Markdown) -->
	<xsl:template match="tt:compare" mode="step-md">
	  <xsl:param name="indent"/>
	  <xsl:variable name="op">
		<xsl:choose>
		  <xsl:when test=".//tt:eq">==</xsl:when>
		  <xsl:when test=".//tt:ne">!=</xsl:when>
		  <xsl:when test=".//tt:gt">&gt;</xsl:when>
		  <xsl:when test=".//tt:ge">&gt;=</xsl:when>
		  <xsl:when test=".//tt:lt">&lt;</xsl:when>
		  <xsl:when test=".//tt:le">&lt;=</xsl:when>
		  <xsl:otherwise>==</xsl:otherwise>
		</xsl:choose>
	  </xsl:variable>

	  <xsl:variable name="lhs"
		select="normalize-space((.//tt:dbobject | .//tt:dbsignal | .//tt:lhs/tt:dbobject | .//tt:left/tt:dbobject)[1])"/>

	  <xsl:variable name="rhsNode" select="(.//tt:eq | .//tt:ne | .//tt:gt | .//tt:ge | .//tt:lt | .//tt:le)[1]"/>
	  <xsl:variable name="rhs"
		select="normalize-space(($rhsNode/tt:valuetable_entry | $rhsNode/tt:value/tt:const | $rhsNode/tt:const | $rhsNode/text())[1])"/>

	  <xsl:value-of select="$indent"/><xsl:text>- `</xsl:text>
	  <xsl:value-of select="$lhs"/><xsl:text> </xsl:text><xsl:value-of select="$op"/><xsl:text> </xsl:text><xsl:value-of select="$rhs"/>
	  <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
	</xsl:template>


  <!-- VARIABLES -->
  <xsl:template match="tt:variables" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- **VARIABLES**</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:variables/tt:variable_definition" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:variable name="nm"  select="normalize-space(tt:name)"/>
    <xsl:variable name="typ" select="normalize-space(tt:type)"/>
    <xsl:variable name="src">
      <xsl:choose>
        <xsl:when test="tt:source/tt:valuetable_entry"><xsl:value-of select="normalize-space(tt:source/tt:valuetable_entry)"/></xsl:when>
        <xsl:when test="tt:source/tt:value/tt:const"><xsl:value-of select="normalize-space(tt:source/tt:value/tt:const)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(tt:source)"/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:value-of select="$indent"/><xsl:text>- `VARIABLE_DEFINITION</xsl:text>
    <xsl:if test="$nm!='' or $typ!='' or $src!=''">
      <xsl:text> </xsl:text><xsl:value-of select="$nm"/>
      <xsl:if test="$typ!=''"><xsl:text> : </xsl:text><xsl:value-of select="$typ"/></xsl:if>
      <xsl:if test="$src!=''"><xsl:text> ← </xsl:text><xsl:value-of select="$src"/></xsl:if>
    </xsl:if>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
    <xsl:apply-templates select="tt:*[not(self::tt:name or self::tt:type or self::tt:source)]" mode="step-md">
      <xsl:with-param name="indent" select="concat($indent,$IND)"/>
    </xsl:apply-templates>
  </xsl:template>

  <xsl:template match="tt:title" mode="step-md">
  <xsl:param name="indent"/>
  <xsl:variable name="tNode"
    select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
  <xsl:variable name="t" select="normalize-space(string($tNode))"/>
  <xsl:value-of select="$indent"/><xsl:text>- _TITLE_</xsl:text>
  <xsl:if test="$t!=''"><xsl:text>: </xsl:text><xsl:value-of select="$t"/></xsl:if>
  <xsl:value-of select="$NL"/>
</xsl:template>

  
  
  <!-- ASSIGNMENT -->
  <xsl:template match="tt:assignment" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `</xsl:text>
    <xsl:value-of select="normalize-space(tt:sink/tt:dbobject)"/><xsl:text> = </xsl:text>
    <xsl:choose>
      <xsl:when test="tt:source/tt:valuetable_entry"><xsl:value-of select="normalize-space(tt:source/tt:valuetable_entry)"/></xsl:when>
      <xsl:when test="tt:source/tt:value/tt:const"><xsl:value-of select="normalize-space(tt:source/tt:value/tt:const)"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="normalize-space(tt:source)"/></xsl:otherwise>
    </xsl:choose>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

 
 <!-- Fallback -->
  <xsl:template match="tt:*" mode="step-md">
    <xsl:param name="indent"/>
    <xsl:value-of select="$indent"/><xsl:text>- `</xsl:text>
    <xsl:value-of select="translate(local-name(), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
    <xsl:text>`</xsl:text><xsl:value-of select="$NL"/>
  </xsl:template>

  <xsl:template match="text()" mode="step-md"/>
</xsl:stylesheet>