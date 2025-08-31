<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0"
  xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0"
  exclude-result-prefixes="tt">

  <xsl:output method="html" encoding="UTF-8"/>

  <!-- Optional filter: fixture title (exact match) -->
  <xsl:param name="fixture" select="''"/>

<xsl:param name="showStepNumbers" select="'false'"/>
<xsl:param name="showActiveFlag"  select="'false'"/>
<xsl:param name="softenPaths"     select="'true'"/>


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
  
  <!-- Keys for fast lookups -->
	<xsl:key name="tc-by-id"   match="tt:tc|tt:tc_definition|*[@tcid]" use="normalize-space(tt:tcid|@tcid)"/>
	<xsl:key name="tc-by-name" match="tt:tc|tt:tc_definition|*[*[local-name()='title' or local-name()='name']]" 
			 use="normalize-space(tt:title|tt:name|*[local-name()='title']|*[local-name()='name'])"/>
	<xsl:key name="fn-by-name" match="*[*[local-name()='name']]" 
			 use="normalize-space(*[local-name()='name'])"/>
	<xsl:key name="var-by-name" match="*[(local-name()='variable_definition')]" 
			 use="normalize-space(*[local-name()='name'])"/>
			 
	<!-- Return a display label for a value node:
		 - const → the const
		 - variable → $VarName (ResolvedConst)  [if a simple const can be resolved]
		 - otherwise → compact string(.) -->
	<xsl:template name="bestValueLabel">
	  <xsl:param name="ctx"/>

	  <!-- Direct constant under the ctx -->
	  <xsl:variable name="const" select="normalize-space($ctx/*[local-name()='const'])"/>

	  <!-- Variable name under the ctx -->
	  <xsl:variable name="varName">
		<xsl:choose>
		  <xsl:when test="normalize-space($ctx/*[local-name()='variable']/*[local-name()='name'])!=''">
			<xsl:value-of select="normalize-space($ctx/*[local-name()='variable']/*[local-name()='name'])"/>
		  </xsl:when>
		  <xsl:otherwise>
			<xsl:value-of select="normalize-space($ctx/*[local-name()='variable'])"/>
		  </xsl:otherwise>
		</xsl:choose>
	  </xsl:variable>

	  <!-- Current test case/definition (for local variable resolution) -->
	  <xsl:variable name="tc"
		select="(ancestor::tt:tc | ancestor::tt:tc_definition |
				 ancestor::*[local-name()='tc' or local-name()='tc_definition'])[last()]"/>

	  <!-- Try local definition first, then global (using the key you already defined) -->
	  <xsl:variable name="localConst"
		select="normalize-space($tc//*[local-name()='variable_definition']
					  [normalize-space(*[local-name()='name'])=$varName]
					  [last()]/*[local-name()='source']/*[local-name()='value']/*[local-name()='const'])"/>

	  <xsl:variable name="globalConst"
		select="normalize-space((key('var-by-name',$varName))[1]
					  /*[local-name()='source']/*[local-name()='value']/*[local-name()='const'])"/>

	  <xsl:variable name="resolved">
		<xsl:choose>
		  <xsl:when test="$localConst!=''">
			<xsl:value-of select="$localConst"/>
		  </xsl:when>
		  <xsl:otherwise>
			<xsl:value-of select="$globalConst"/>
		  </xsl:otherwise>
		</xsl:choose>
	  </xsl:variable>

	  <!-- Emit the label -->
	  <xsl:choose>
		<xsl:when test="$const!=''">
		  <xsl:value-of select="$const"/>
		</xsl:when>
		<xsl:when test="$varName!=''">
		  <xsl:text>$</xsl:text><xsl:value-of select="$varName"/>
		  <xsl:if test="$resolved!=''">
			<xsl:text> (</xsl:text><xsl:value-of select="$resolved"/><xsl:text>)</xsl:text>
		  </xsl:if>
		</xsl:when>
		<xsl:otherwise>
		  <xsl:value-of select="normalize-space(string($ctx))"/>
		</xsl:otherwise>
	  </xsl:choose>
	</xsl:template>
	
	
	<!-- Helper: print one WAIT line from a time/timeout 'base' node -->
<xsl:template name="emit-wait-line">
  <xsl:param name="base"/>

  <xsl:variable name="unit" select="normalize-space(($base//*[local-name()='unit'])[1])"/>
  <xsl:variable name="cval" select="normalize-space(($base//*[local-name()='const'])[1])"/>

  <xsl:variable name="display">
    <xsl:choose>
      <xsl:when test="$cval!=''">
        <xsl:value-of select="$cval"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="bestValueLabel">
          <xsl:with-param name="ctx" select="($base//*[local-name()='value'])[1]"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <li>
    <code>
      <xsl:text>WAIT </xsl:text>
      <xsl:value-of select="$display"/>
      <xsl:if test="$unit!=''">
        <xsl:text> </xsl:text>     <!-- explicit space, never collapsed by XSLT -->
        <xsl:value-of select="$unit"/>
      </xsl:if>
    </code>
  </li>
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

	  <xsl:variable name="byId"   select="(key('tc-by-id', $id))[1]"/>
	  <xsl:variable name="byName" select="(key('tc-by-name', $name))[1]"/>

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
	<!-- TTFUNC call: print call; inline body if a same-file definition exists -->
	<xsl:template match="tt:ttfunction" mode="step">
	  <xsl:param name="indent"/>
	  <xsl:variable name="fname" select="normalize-space(tt:name)"/>

	  <li>
		<code>TTFUNC <xsl:value-of select="$fname"/>(</code>
		<xsl:for-each select="tt:param">
		  <xsl:if test="position() &gt; 1"><xsl:text>, </xsl:text></xsl:if>
		  <code>
			<xsl:call-template name="bestValueLabel">
			  <xsl:with-param name="ctx" select="tt:value"/>
			</xsl:call-template>
		  </code>
		</xsl:for-each>

		<code>)</code>

		<!-- Find a likely definition node elsewhere in the file.
			 A) any element with child <name> == $fname (namespace-agnostic), or
			 B) an element whose local-name() equals the function name,
			 and which has step-like descendants. -->
		<xsl:variable name="def"
		  select="(
			//*[
			  *[local-name()='name' and normalize-space(.)=$fname]
			  and (descendant::*[local-name()='set']
				   or descendant::*[local-name()='wait']
				   or descendant::*[local-name()='statechange']
				   or descendant::*[local-name()='statecheck']
				   or descendant::*[local-name()='variables']
				   or descendant::*[local-name()='caplfunction']
				   or descendant::*[local-name()='caplinline']
				   or descendant::*[local-name()='occurrence_count']
				   or descendant::*[local-name()='check_deactivation']
				   or descendant::*[local-name()='awaitvaluematch']
				   or descendant::*[local-name()='ttfunction']
				   or descendant::*[local-name()='netfunction']
				   or descendant::*[local-name()='diagservice']
			  )
			  and not(self::tt:ttfunction)
			]
			|
			//*[
			  local-name()=$fname
			  and (descendant::*[local-name()='set'] or descendant::*[local-name()='wait'])
			]
		  )[1]"/>

		<xsl:choose>
		  <xsl:when test="$def">
			<span class="muted"> — inlined</span>
			<ul>
			  <!-- Render the definition’s content; skip meta -->
			  <xsl:apply-templates select="$def/*[
				not(local-name()='name' or local-name()='parameters' or
					local-name()='title' or local-name()='attributes' or
					local-name()='arguments' or local-name()='description')
			  ]" mode="step"/>
			</ul>
		  </xsl:when>
		  <xsl:otherwise>
			<span class="muted"> — definition not found (likely external)</span>
		  </xsl:otherwise>
		</xsl:choose>
	  </li>
	</xsl:template>


	  <xsl:template match="tt:netfunction" mode="step">
		<li><code>NET <xsl:value-of select="tt:class"/>.<xsl:value-of select="tt:name"/>(<xsl:call-template name="join-params"><xsl:with-param name="ctx" select="."/></xsl:call-template>)</code></li>
	  </xsl:template>

		




  <!-- SET (namespace-agnostic) -->
	<xsl:template match="tt:set | *[local-name()='set']" mode="step">
	  <li>
		<code>SET</code>
		<ul>
		  <xsl:for-each select="*[local-name()='in']/*[local-name()='assignment']">
			<li>
			  <code>
				<xsl:value-of select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
				<xsl:text> = </xsl:text>
				<xsl:choose>
				  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value']/*[local-name()='const'])!=''">
					<xsl:value-of select="normalize-space(*[local-name()='source']/*[local-name()='value']/*[local-name()='const'])"/>
				  </xsl:when>
				  <xsl:otherwise>
					<xsl:value-of select="normalize-space(*[local-name()='source'])"/>
				  </xsl:otherwise>
				</xsl:choose>
			  </code>
			</li>
		  </xsl:for-each>
		</ul>
	  </li>
	</xsl:template>

  <xsl:template match="tt:awaitvaluematch" mode="step">
	  <li>
		<code>AWAITVALUEMATCH timeout=</code>
		<code>
		  <xsl:call-template name="bestValueLabel">
			<xsl:with-param name="ctx" select="tt:timeout/tt:value"/>
		  </xsl:call-template>
		  <xsl:if test="normalize-space(tt:timeout/tt:unit)!=''">
			<xsl:text> </xsl:text><xsl:value-of select="normalize-space(tt:timeout/tt:unit)"/>
		  </xsl:if>
		</code>
		<ul>
		  <xsl:apply-templates select="tt:compare" mode="step"/>
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

  <!-- STATECHANGE -->
<xsl:template
  match="tt:statechange
       | *[local-name()='statechange'
          or local-name()='stateChange']"
  mode="step">

  <li><strong>STATECHANGE</strong>
    <ul>
      <!-- IN -->
      <xsl:if test="tt:in
                 | *[local-name()='in']">
        <li><em>IN</em>
          <ul>
            <xsl:apply-templates select="tt:in/* | *[local-name()='in']/*" mode="step"/>
          </ul>
        </li>
      </xsl:if>

	  
	        <!-- WAIT: list any descendant <wait> or <timeout> and print value + unit -->

<xsl:variable name="waitNodes" select=".//*[local-name()='wait' or local-name()='timeout']"/>
<xsl:if test="$waitNodes">
  <li><em>WAIT</em>
    <ul>
      <xsl:for-each select="$waitNodes">
        <xsl:variable name="base"
          select="(.//*[local-name()='time' or local-name()='timeout']
                  | self::node())[1]"/>
        <xsl:call-template name="emit-wait-line">
          <xsl:with-param name="base" select="$base"/>
        </xsl:call-template>
      </xsl:for-each>
    </ul>
  </li>
</xsl:if>



      <!-- EXPECTED -->
      <xsl:if test="tt:expected
                 | *[local-name()='expected']">
        <li><em>EXPECTED</em>
          <ul>
            <xsl:apply-templates select="tt:expected/* | *[local-name()='expected']/*" mode="step"/>
          </ul>
        </li>
      </xsl:if>
    </ul>
  </li>
</xsl:template>

	
	
	
	<!-- STATECHECK -->
	<xsl:template
	  match="tt:statecheck
		   | *[local-name()='statecheck'
			  or local-name()='stateCheck']"
	  mode="step">

	  <li><strong>STATECHECK</strong>
		<ul>
		  <xsl:if test="normalize-space(tt:title | *[local-name()='title'])!=''">
			<li><em>TITLE:</em>
			  <xsl:text> </xsl:text>
			  <code><xsl:value-of select="normalize-space(tt:title | *[local-name()='title'])"/></code>
			</li>
		  </xsl:if>

		  <xsl:if test="tt:wait | *[local-name()='wait'] | tt:timeout | *[local-name()='timeout']">
			<li><em>WAIT</em>
			  <ul>
				<xsl:apply-templates
				  select="tt:wait | *[local-name()='wait'] | tt:timeout | *[local-name()='timeout']"
				  mode="step"/>
			  </ul>
			</li>
		  </xsl:if>

		  <xsl:if test="tt:expected | *[local-name()='expected']">
			<li><em>EXPECTED</em>
			  <ul>
				<xsl:apply-templates select="tt:expected/* | *[local-name()='expected']/*" mode="step"/>
			  </ul>
			</li>
		  </xsl:if>
		</ul>
	  </li>
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

	<!-- COMMENT -->
	<xsl:template match="tt:comment" mode="step">
	  <xsl:param name="indent"/>
	  <xsl:variable name="msg">
		<xsl:choose>
		  <xsl:when test="normalize-space(tt:text)!=''">
			<xsl:value-of select="normalize-space(tt:text)"/>
		  </xsl:when>
		  <xsl:when test="normalize-space(tt:title)!=''">
			<xsl:value-of select="normalize-space(tt:title)"/>
		  </xsl:when>
		  <xsl:when test="normalize-space(tt:message)!=''">
			<xsl:value-of select="normalize-space(tt:message)"/>
		  </xsl:when>
		  <xsl:when test="normalize-space(.//tt:value/tt:const)!=''">
			<xsl:value-of select="normalize-space(.//tt:value/tt:const)"/>
		  </xsl:when>
		  <xsl:otherwise>
			<xsl:value-of select="normalize-space(string(.))"/>
		  </xsl:otherwise>
		</xsl:choose>
	  </xsl:variable>

	  <li>
		<code>COMMENT</code>
		<xsl:if test="$msg!=''">
		  <span class="muted"> — <xsl:value-of select="$msg"/></span>
		</xsl:if>
	  </li>
	</xsl:template>

	<!-- WAIT step -->
	<xsl:template match="tt:wait | *[local-name()='wait']" mode="step">
	  <xsl:variable name="base"
		select="(.//*[local-name()='time' or local-name()='timeout']
				| *[local-name()='time' or local-name()='timeout'])[1]"/>
	  <xsl:if test="$base">
		<xsl:call-template name="emit-wait-line">
		  <xsl:with-param name="base" select="$base"/>
		</xsl:call-template>
	  </xsl:if>
	</xsl:template>

	<!-- TIMEOUT step (if your files ever use direct <timeout>) -->
	<xsl:template match="tt:timeout | *[local-name()='timeout']" mode="step">
	  <xsl:call-template name="emit-wait-line">
		<xsl:with-param name="base" select="."/>
	  </xsl:call-template>
	</xsl:template>





  <!-- Fallback -->
  <xsl:template match="tt:*" mode="step">
  <li>
  <code><xsl:value-of select="translate(local-name(), 'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/></code>
  <xsl:variable name="msg" select="normalize-space(./tt:text|./tt:title|./tt:message|./*[local-name()='text' or local-name()='title' or local-name()='message'])"/>
  <xsl:if test="$msg!=''"><span class="muted"> — <xsl:value-of select="$msg"/></span></xsl:if>
</li>

  </xsl:template>
  <xsl:template match="text()" mode="step"/>
  
  



</xsl:stylesheet>