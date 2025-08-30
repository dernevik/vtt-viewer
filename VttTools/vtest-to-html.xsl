<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0"
  exclude-result-prefixes="tt">

  <xsl:output method="html" encoding="UTF-8"/>

  <!-- Optional filter: fixture title (exact match) -->
  <xsl:param name="fixture" select="''"/>

  <!-- Join function/step parameters -->
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

  <!-- ========== Root ========== -->
  <xsl:template match="/">
    <html>
      <head>
        <meta charset="utf-8"/>
        <title>Test Listing</title>
        <style>
          body{font-family:Segoe UI,Arial,sans-serif;line-height:1.35;padding:24px;max-width:1100px}
          h1,h2,h3,h4{margin:.8em 0 .4em}
          ul{margin:.2em 0 1em 1.25em}
          li{margin:.15em 0}
          code{font-family:ui-monospace,Consolas,Menlo,monospace;white-space:pre-wrap;word-break:break-word}
          .fixture{margin-bottom:1.6em}
          .muted{opacity:.7}
        </style>
      </head>
      <body>
        <h1>Test Listing</h1>

        <xsl:choose>
          <xsl:when test="normalize-space($fixture)!=''">
            <xsl:apply-templates select="//tt:tf[normalize-space(tt:title)=normalize-space($fixture)]"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:apply-templates select="//tt:tt/tt:tf"/>
          </xsl:otherwise>
        </xsl:choose>

        <xsl:if test="normalize-space($fixture)='' and //tt:tc_definitions/tt:tc_definition">
          <h2>Test Case Definitions</h2>
          <xsl:apply-templates select="//tt:tc_definitions/tt:tc_definition"/>
        </xsl:if>
      </body>
    </html>
  </xsl:template>

  <!-- ========== Fixture ========== -->
  <xsl:template match="tt:tf">
    <div class="fixture" id="{normalize-space(tt:title)}">
      <h2>Fixture: <xsl:value-of select="normalize-space(tt:title)"/></h2>
      <xsl:apply-templates select="tt:preparation"/>
      <xsl:apply-templates select="tt:ts"/>
      <xsl:apply-templates select="tt:tc"/>
      <xsl:apply-templates select="tt:tf"/>
      <xsl:apply-templates select="tt:completion"/>
    </div>
  </xsl:template>

  <!-- ========== Test sequence (expand referenced tests) ========== -->
  <xsl:template match="tt:ts">
    <h3>Test Sequence</h3>
    <xsl:if test="normalize-space(tt:title)!=''">
      <p class="muted"><xsl:value-of select="normalize-space(tt:title)"/></p>
    </xsl:if>
    <ul><xsl:apply-templates select="tt:tttestcase"/></ul>
  </xsl:template>

  <xsl:template match="tt:tttestcase">
    <xsl:variable name="id"   select="normalize-space(tt:tcid)"/>
    <xsl:variable name="name" select="normalize-space(tt:name)"/>

    <xsl:variable name="byId"
      select="(//tt:tc[normalize-space(tt:tcid)=$id] |
               //tt:tc_definition[normalize-space(tt:tcid)=$id])[1]"/>
    <xsl:variable name="byName"
      select="(//tt:tc[normalize-space(tt:title)=$name] |
               //tt:tc_definition[normalize-space(tt:name)=$name])[1]"/>

    <li>
      <code>
        <xsl:value-of select="$name"/>
        <xsl:if test="$id!=''"> [<xsl:value-of select="$id"/>]</xsl:if>
      </code>
      <xsl:choose>
        <xsl:when test="$byId"><ul><xsl:apply-templates select="$byId" mode="inline"/></ul></xsl:when>
        <xsl:when test="$byName"><span class="muted"> — matched by name</span><ul><xsl:apply-templates select="$byName" mode="inline"/></ul></xsl:when>
        <xsl:otherwise><span class="muted"> — definition not found</span></xsl:otherwise>
      </xsl:choose>
    </li>
  </xsl:template>

  <!-- Inline expansion for tc / tc_definition -->
  <xsl:template match="tt:tc | tt:tc_definition" mode="inline">
    <xsl:if test="tt:preparation">
      <li><strong>Preparation</strong><ul><xsl:apply-templates select="tt:preparation/tt:*" mode="step"/></ul></li>
    </xsl:if>
    <xsl:if test="tt:*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]">
      <li><strong>Steps</strong>
        <ul>
          <xsl:apply-templates select="tt:*[
            not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or
                self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)
          ]" mode="step"/>
        </ul>
      </li>
    </xsl:if>
    <xsl:if test="tt:completion">
      <li><strong>Completion</strong><ul><xsl:apply-templates select="tt:completion/tt:*" mode="step"/></ul></li>
    </xsl:if>
  </xsl:template>

  <!-- Standalone tc/definition headings (when listing all) -->
  <xsl:template match="tt:tc | tt:tc_definition">
    <xsl:variable name="title" select="normalize-space(tt:title)"/>
    <xsl:variable name="id"    select="normalize-space(tt:tcid)"/>
    <h3>
      <xsl:choose>
        <xsl:when test="self::tt:tc_definition">TC Definition: </xsl:when>
        <xsl:otherwise>TestCase: </xsl:otherwise>
      </xsl:choose>
      <xsl:value-of select="$title"/>
      <xsl:if test="$id!=''"> <code>[<xsl:value-of select="$id"/>]</code></xsl:if>
    </h3>
    <xsl:apply-templates select="." mode="inline"/>
  </xsl:template>

  <!-- Prep / Completion wrappers -->
  <xsl:template match="tt:preparation | tt:completion">
    <h3>
      <xsl:choose><xsl:when test="self::tt:preparation">Preparation</xsl:when><xsl:otherwise>Completion</xsl:otherwise></xsl:choose>
    </h3>
    <ul><xsl:apply-templates select="tt:*" mode="step"/></ul>
  </xsl:template>

  <!-- ========== Step renderers ========== -->
  <xsl:template match="tt:ttfunction" mode="step">
    <li><code>TTFUNC <xsl:value-of select="tt:name"/>(<xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>)</code></li>
  </xsl:template>

  <!-- CAPL call with best-effort source hint -->
	<xsl:template match="tt:caplfunction" mode="step">
	  <li>
		<code>CAPL <xsl:value-of select="tt:name"/>(<xsl:call-template name="join-params">
		  <xsl:with-param name="ctx" select="."/>
		</xsl:call-template>)</code>
		<!-- try a few common places a path might appear -->
		<xsl:variable name="src"
		  select="normalize-space((
			tt:file/tt:path |
			tt:sourcefile |
			tt:impl/tt:capl/tt:path |
			@file | @path
		  )[1])"/>
		<xsl:choose>
		  <xsl:when test="$src!=''">
			<span class="muted"> — file <code><xsl:value-of select="$src"/></code></span>
		  </xsl:when>
		  <xsl:otherwise>
			<span class="muted"> — external CAPL (path not in VTT)</span>
		  </xsl:otherwise>
		</xsl:choose>
	  </li>
	</xsl:template>

  <xsl:template match="tt:netfunction" mode="step">
    <li><code>NET <xsl:value-of select="tt:class"/>.<xsl:value-of select="tt:name"/>(<xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>)</code></li>
  </xsl:template>

  <xsl:template match="tt:wait" mode="step">
    <li><code>WAIT <xsl:value-of select="normalize-space(tt:time/tt:value/tt:const)"/> <xsl:value-of select="normalize-space(tt:time/tt:unit)"/></code></li>
  </xsl:template>

  <xsl:template match="tt:set" mode="step">
    <li><code>SET </code><code>
      <xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:sink/tt:dbobject)"/>
      <xsl:text> = </xsl:text>
      <xsl:choose>
        <xsl:when test="tt:in/tt:assignment/tt:source/tt:valuetable_entry"><xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:source/tt:valuetable_entry)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(tt:in/tt:assignment/tt:source/tt:value/tt:const)"/></xsl:otherwise>
      </xsl:choose>
    </code></li>
  </xsl:template>

  <xsl:template match="tt:awaitvaluematch" mode="step">
    <li>
      <code>AWAITVALUEMATCH timeout=<xsl:value-of select="normalize-space(tt:timeout/tt:value/tt:const)"/><xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/></code>
      <ul><xsl:apply-templates select="tt:compare" mode="step"/></ul>
    </li>
  </xsl:template>

  <xsl:template match="tt:diagservice" mode="step">
    <li><code>DIAG <xsl:value-of select="normalize-space(tt:service)"/></code></li>
  </xsl:template>

  <xsl:template match="tt:for" mode="step">
    <li>
      <code>FOR <xsl:value-of select="normalize-space(tt:loopvar)"/> from <xsl:value-of select="normalize-space(tt:startvalue/tt:const)"/>
      to <xsl:value-of select="normalize-space(tt:stopvalue/tt:const)"/> step <xsl:value-of select="normalize-space(tt:increment/tt:const)"/></code>
      <ul>
        <xsl:apply-templates select="tt:*[
          not(self::tt:title or self::tt:loopvar or self::tt:loopvartype or
              self::tt:startvalue or self::tt:stopvalue or self::tt:increment)
        ]" mode="step"/>
      </ul>
    </li>
  </xsl:template>

  <xsl:template match="tt:foreach" mode="step">
    <li>
      <code>FOREACH <xsl:value-of select="normalize-space(tt:loopvar)"/></code>
      <ul>
        <xsl:apply-templates select="tt:*[
          not(self::tt:title or self::tt:loopvar or self::tt:listparameter)
        ]" mode="step"/>
      </ul>
    </li>
  </xsl:template>

  <!-- ===== Composite: STATECHANGE ===== -->
  <xsl:template match="tt:statechange" mode="step">
    <li>
      <code>STATECHANGE
        <xsl:variable name="desc">
          <xsl:choose>
            <xsl:when test="normalize-space(tt:name)!=''"><xsl:value-of select="normalize-space(tt:name)"/></xsl:when>
            <xsl:when test="normalize-space(tt:state)!=''"><xsl:value-of select="normalize-space(tt:state)"/></xsl:when>
            <xsl:when test="normalize-space(tt:targetstate)!=''"><xsl:value-of select="normalize-space(tt:targetstate)"/></xsl:when>
            <xsl:when test="normalize-space(tt:target)!=''"><xsl:value-of select="normalize-space(tt:target)"/></xsl:when>
            <xsl:otherwise/>
          </xsl:choose>
        </xsl:variable>
        <xsl:if test="normalize-space($desc)!=''"> <xsl:value-of select="$desc"/></xsl:if>
      </code>
      <ul><xsl:apply-templates select="tt:*" mode="step"/></ul>
    </li>
  </xsl:template>

  <!-- STATECHANGE sections -->
  <xsl:template match="tt:statechange/tt:title" mode="step">
    <xsl:variable name="tNode" select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
    <xsl:variable name="t" select="normalize-space(string($tNode))"/>
    <xsl:if test="$t!=''"><li><em>TITLE</em>: <xsl:value-of select="$t"/></li></xsl:if>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:in" mode="step">
    <li><code>IN</code><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:wait" mode="step">
    <li><code>WAIT
      <xsl:text> </xsl:text>
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
      </xsl:choose></code>
    </li>
  </xsl:template>

  <xsl:template match="tt:statechange/tt:expected" mode="step">
    <li><strong>EXPECTED</strong><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <!-- ===== Composite: STATECHECK ===== -->
  <xsl:template match="tt:statecheck" mode="step">
    <li><code>STATECHECK</code><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <xsl:template match="tt:statecheck/tt:title" mode="step">
    <xsl:variable name="tNode" select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
    <xsl:variable name="t" select="normalize-space(string($tNode))"/>
    <xsl:if test="$t!=''"><li><em>TITLE</em>: <xsl:value-of select="$t"/></li></xsl:if>
  </xsl:template>

  <xsl:template match="tt:statecheck/tt:expected" mode="step">
    <li><strong>EXPECTED</strong><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <!-- ===== Comparisons (==, !=, >, >=, <, <=) ===== -->
  <xsl:template match="tt:compare" mode="step">
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
    <xsl:variable name="lhs" select="normalize-space((.//tt:dbobject | .//tt:dbsignal | .//tt:lhs/tt:dbobject | .//tt:left/tt:dbobject)[1])"/>
    <xsl:variable name="rhsNode" select="(.//tt:eq | .//tt:ne | .//tt:gt | .//tt:ge | .//tt:lt | .//tt:le)[1]"/>
    <xsl:variable name="rhs" select="normalize-space(($rhsNode/tt:valuetable_entry | $rhsNode/tt:value/tt:const | $rhsNode/tt:const | $rhsNode/text())[1])"/>
    <li><code><xsl:value-of select="$lhs"/> <xsl:value-of select="$op"/> <xsl:value-of select="$rhs"/></code></li>
  </xsl:template>

  <!-- ===== VARIABLES & ASSIGNMENT ===== -->
  <xsl:template match="tt:variables" mode="step">
    <li><code>VARIABLES</code><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <xsl:template match="tt:variables/tt:variable_definition" mode="step">
    <li>
      <code>VARIABLE_DEFINITION</code>
      <xsl:variable name="nm"  select="normalize-space(tt:name)"/>
      <xsl:variable name="typ" select="normalize-space(tt:type)"/>
      <xsl:variable name="src">
        <xsl:choose>
          <xsl:when test="tt:source/tt:valuetable_entry"><xsl:value-of select="normalize-space(tt:source/tt:valuetable_entry)"/></xsl:when>
          <xsl:when test="tt:source/tt:value/tt:const"><xsl:value-of select="normalize-space(tt:source/tt:value/tt:const)"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="normalize-space(tt:source)"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:if test="$nm!='' or $typ!='' or $src!=''">
        <xsl:text> </xsl:text><code><xsl:value-of select="$nm"/>
          <xsl:if test="$typ!=''"> : <xsl:value-of select="$typ"/></xsl:if>
          <xsl:if test="$src!=''"> ← <xsl:value-of select="$src"/></xsl:if>
        </code>
      </xsl:if>
      <ul><xsl:apply-templates select="tt:*[not(self::tt:name or self::tt:type or self::tt:source)]" mode="step"/></ul>
    </li>
  </xsl:template>

  <xsl:template match="tt:assignment" mode="step">
    <li><code>
      <xsl:value-of select="normalize-space(tt:sink/tt:dbobject)"/>
      <xsl:text> = </xsl:text>
      <xsl:choose>
        <xsl:when test="tt:source/tt:valuetable_entry"><xsl:value-of select="normalize-space(tt:source/tt:valuetable_entry)"/></xsl:when>
        <xsl:when test="tt:source/tt:value/tt:const"><xsl:value-of select="normalize-space(tt:source/tt:value/tt:const)"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="normalize-space(tt:source)"/></xsl:otherwise>
      </xsl:choose>
    </code></li>
  </xsl:template>

  <!-- Standalone TITLE as a step (skip if empty) -->
  <xsl:template match="tt:title" mode="step">
    <xsl:variable name="tNode" select="( @value | @text | .//tt:text | .//tt:value/tt:const | .//tt:const | .//text() )[1]"/>
    <xsl:variable name="t" select="normalize-space(string($tNode))"/>
    <xsl:if test="$t!=''"><li><em>TITLE</em>: <xsl:value-of select="$t"/></li></xsl:if>
  </xsl:template>

	<!-- OCCURRENCE_COUNT: show title/limits and list PDUs -->
	<xsl:template match="tt:occurrence_count" mode="step">
	  <li>
		<code>OCCURRENCE_COUNT</code>
		<xsl:if test="normalize-space(tt:title)!=''">
		  <span class="muted"> — <xsl:value-of select="normalize-space(tt:title)"/></span>
		</xsl:if>
		<ul>
		  <xsl:if test="tt:mincount or tt:maxcount or tt:timeout">
			<li class="muted">
			  <xsl:text>limits: </xsl:text>
			  <xsl:if test="tt:mincount">min=<code><xsl:value-of select="normalize-space(tt:mincount)"/></code></xsl:if>
			  <xsl:if test="tt:mincount and (tt:maxcount or tt:timeout)"><xsl:text>; </xsl:text></xsl:if>
			  <xsl:if test="tt:maxcount">max=<code><xsl:value-of select="normalize-space(tt:maxcount)"/></code></xsl:if>
			  <xsl:if test="tt:maxcount and tt:timeout"><xsl:text>; </xsl:text></xsl:if>
			  <xsl:if test="tt:timeout">
				timeout=<code><xsl:value-of select="normalize-space(tt:timeout/tt:value/tt:const)"/></code>
				<xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/>
			  </xsl:if>
			</li>
		  </xsl:if>

		  <!-- Optional join condition (e.g., AND/OR) -->
		  <xsl:if test="normalize-space(tt:joincondition)!=''">
			<li class="muted">join=<code><xsl:value-of select="normalize-space(tt:joincondition)"/></code></li>
		  </xsl:if>

		  <!-- The watched PDUs -->
		  <xsl:for-each select="tt:objects/tt:pdu">
			<li><code>PDU </code><code><xsl:value-of select="normalize-space(tt:dbobject)"/></code></li>
		  </xsl:for-each>
		</ul>
	  </li>
	</xsl:template>


	<!-- CHECK_DEACTIVATION: stops the (latest or referenced) monitor -->
	<xsl:template match="tt:check_deactivation" mode="step">
	  <li>
		<code>CHECK_DEACTIVATION</code>
		<xsl:choose>
		  <xsl:when test="normalize-space(tt:checkid)!=''">
			<span class="muted"> — id=<code><xsl:value-of select="normalize-space(tt:checkid)"/></code></span>
		  </xsl:when>
		  <xsl:when test="normalize-space(tt:title)!=''">
			<span class="muted"> — <xsl:value-of select="normalize-space(tt:title)"/></span>
		  </xsl:when>
		  <xsl:otherwise>
			<span class="muted"> — deactivate last started</span>
		  </xsl:otherwise>
		</xsl:choose>
	  </li>
	</xsl:template>


	<!-- CAPLINLINE: show inline CAPL program block -->
	<xsl:template match="tt:caplinline" mode="step">
	  <li>
		<code>CAPLINLINE</code>
		<xsl:if test="normalize-space(tt:title)!=''">
		  <span class="muted"> — <xsl:value-of select="normalize-space(tt:title)"/></span>
		</xsl:if>
		<div style="margin:.25em 0 .6em .5em;border:1px solid #e0e0e0;border-radius:6px;padding:.6em .8em;overflow:auto">
		  <pre style="margin:0"><code><xsl:value-of select="tt:code"/></code></pre>
		</div>
	  </li>
	</xsl:template>


	<!-- NOVALUECHANGE: start “no value change” monitor for a signal -->
	<xsl:template match="tt:novaluechange" mode="step">
	  <li>
		<code>NOVALUECHANGE</code>
		<xsl:if test="normalize-space(tt:title)!=''">
		  <span class="muted"> — <xsl:value-of select="normalize-space(tt:title)"/></span>
		</xsl:if>
		<ul>
		  <li><code><xsl:value-of select="normalize-space(tt:dbobject)"/></code></li>
		</ul>
	  </li>
	</xsl:template>





  <!-- Fallback -->
  <xsl:template match="tt:*" mode="step">
    <li><code><xsl:value-of select="translate(local-name(), 'abcdefghijklmnopqrstuvwxyz', 'ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/></code></li>
  </xsl:template>
  <xsl:template match="text()" mode="step"/>

</xsl:stylesheet>