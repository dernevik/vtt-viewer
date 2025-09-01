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


<!-- ========== Pretty path helpers ========== -->
<!-- Return the last token after '|' -->
<xsl:template name="last-token">
  <xsl:param name="s"/>
  <xsl:choose>
    <xsl:when test="contains($s,'|')">
      <xsl:call-template name="last-token">
        <xsl:with-param name="s" select="substring-after($s,'|')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- Join everything except the last token with '::' -->
<xsl:template name="join-namespace">
  <xsl:param name="s"/>
  <xsl:if test="contains($s,'|')">
    <xsl:variable name="head" select="substring-before($s,'|')"/>
    <xsl:variable name="tail" select="substring-after($s,'|')"/>
    <xsl:choose>
      <xsl:when test="contains($tail,'|')">
        <xsl:value-of select="$head"/><xsl:text>::</xsl:text>
        <xsl:call-template name="join-namespace">
          <xsl:with-param name="s" select="$tail"/>
        </xsl:call-template>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$head"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:if>
</xsl:template>

<!-- Emit a softened/human path for DBSignal / SysVar / PDU (fallback to raw) -->
<xsl:template name="prettyPath">
  <xsl:param name="text"/>
  <xsl:variable name="raw" select="normalize-space($text)"/>

  <!-- remove every *_BEGIN_OF_OBJECT| anywhere -->
  <xsl:variable name="noBegin">
    <xsl:call-template name="strip-begin-markers">
      <xsl:with-param name="s" select="$raw"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- stop at first END_OF_OBJECT... -->
  <xsl:variable name="preEnd"
    select="substring-before(concat($noBegin,'|END_OF_OBJECT'),'|END_OF_OBJECT')"/>

  <!-- drop leading pure-digit tokens (e.g., 1|255|...) -->
  <xsl:variable name="core0">
    <xsl:call-template name="drop-leading-digits">
      <xsl:with-param name="s" select="$preEnd"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- family-specific front-token cleanup -->
  <xsl:choose>

    <!-- ===== DBSignal -->
<xsl:when test="starts-with($raw,'DBSignal')">
  <xsl:call-template name="prettyDbSignal">
    <xsl:with-param name="text" select="$raw"/>
  </xsl:call-template>
</xsl:when>


	
	
	

    <!-- ===== SysVar: drop 'SysVar*' front token and trailing numeric tokens, then format -->
    <xsl:when test="starts-with($raw,'SysVar')">
      <!-- drop leading 'SysVar*' token if present -->
      <xsl:variable name="h0" select="substring-before(concat($core0,'|'),'|')"/>
      <xsl:variable name="t0" select="substring-after($core0,'|')"/>
      <xsl:variable name="core1">
        <xsl:choose>
          <xsl:when test="starts-with($h0,'SysVar')"><xsl:value-of select="$t0"/></xsl:when>
          <xsl:otherwise><xsl:value-of select="$core0"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>

      <!-- also strip trailing numeric indices like |-1|0 -->
      <xsl:variable name="core">
        <xsl:call-template name="drop-trailing-digits">
          <xsl:with-param name="s" select="$core1"/>
        </xsl:call-template>
      </xsl:variable>

      <xsl:variable name="ns">
        <xsl:call-template name="join-namespace"><xsl:with-param name="s" select="$core"/></xsl:call-template>
      </xsl:variable>
      <xsl:variable name="var">
        <xsl:call-template name="last-token"><xsl:with-param name="s" select="$core"/></xsl:call-template>
      </xsl:variable>

      <xsl:choose>
        <xsl:when test="normalize-space($var)!=''">
          <xsl:text>SysVar </xsl:text>
          <xsl:value-of select="normalize-space($ns)"/><xsl:text>::</xsl:text>
          <xsl:value-of select="normalize-space($var)"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$raw"/></xsl:otherwise>
      </xsl:choose>
    </xsl:when>

    <!-- ===== PDU -->
    <xsl:when test="starts-with($raw,'PDU') or starts-with($raw,'Pdu') or contains($raw,'DBFrameOrPDU')">
      <xsl:variable name="bus"  select="substring-before($core0,'|')"/>
      <xsl:variable name="t1"   select="substring-after($core0,'|')"/>
      <xsl:variable name="cfg"  select="substring-before($t1,'|')"/>
      <xsl:variable name="pdu">
        <xsl:choose>
          <xsl:when test="contains($t1,'|')">
            <xsl:call-template name="last-token"><xsl:with-param name="s" select="$t1"/></xsl:call-template>
          </xsl:when>
          <xsl:otherwise><xsl:value-of select="$t1"/></xsl:otherwise>
        </xsl:choose>
      </xsl:variable>
      <xsl:choose>
        <xsl:when test="$bus!='' and $cfg!='' and normalize-space($pdu)!=''">
          <xsl:text>PDU </xsl:text>
          <xsl:value-of select="$bus"/><xsl:text>/</xsl:text>
          <xsl:value-of select="$cfg"/><xsl:text>: </xsl:text>
          <xsl:value-of select="normalize-space($pdu)"/>
        </xsl:when>
        <xsl:otherwise><xsl:value-of select="$raw"/></xsl:otherwise>
      </xsl:choose>
    </xsl:when>

    <!-- ===== fallback -->
    <xsl:otherwise><xsl:value-of select="$raw"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>




<!-- pduLabel: extract a readable PDU name from DBFrameOrPDU paths -->
<xsl:template name="pduLabel">
  <xsl:param name="path"/>

  <!-- Prefer the FrameData slice: ... FrameData_BEGIN_OF_OBJECT | ... | END_OF_OBJECT_FrameData -->
  <xsl:variable name="frameSlice"
    select="substring-before(
              substring-after($path,'FrameData_BEGIN_OF_OBJECT|'),
              '|END_OF_OBJECT_FrameData')"/>

  <xsl:variable name="fromFrame">
    <xsl:call-template name="lastAlphaToken">
      <xsl:with-param name="s" select="$frameSlice"/>
    </xsl:call-template>
  </xsl:variable>

  <xsl:choose>
    <!-- Got a decent-looking name from the FrameData slice -->
    <xsl:when test="normalize-space($fromFrame)!=''">
      <xsl:value-of select="normalize-space($fromFrame)"/>
    </xsl:when>

    <!-- Fallback: take the token before the FINAL END_OF_OBJECT marker -->
    <xsl:otherwise>
      <xsl:variable name="base"
        select="substring-before(concat($path,'|END_OF_OBJECT_'),'|END_OF_OBJECT_')"/>
      <xsl:call-template name="after-last">
        <xsl:with-param name="s" select="$base"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>


	<!-- strip all "..._BEGIN_OF_OBJECT|" markers from a path (recursively) -->
	<xsl:template name="strip-begin-markers">
	  <xsl:param name="s"/>
	  <xsl:choose>
		<xsl:when test="contains($s,'_BEGIN_OF_OBJECT|')">
		  <xsl:call-template name="strip-begin-markers">
			<xsl:with-param name="s"
			  select="concat(substring-before($s,'_BEGIN_OF_OBJECT|'),
							 substring-after($s,'_BEGIN_OF_OBJECT|'))"/>
		  </xsl:call-template>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
	  </xsl:choose>
	</xsl:template>

	<!-- drop all leading tokens that are purely digits (e.g., 1|255|... ) -->
	<xsl:template name="drop-leading-digits">
	  <xsl:param name="s"/>
	  <xsl:choose>
		<xsl:when test="contains($s,'|')">
		  <xsl:variable name="head" select="substring-before($s,'|')"/>
		  <xsl:variable name="tail" select="substring-after($s,'|')"/>
		  <!-- numeric? translate removes digits; empty => all digits -->
		  <xsl:choose>
			<xsl:when test="translate($head,'0123456789','')=''">
			  <xsl:call-template name="drop-leading-digits">
				<xsl:with-param name="s" select="$tail"/>
			  </xsl:call-template>
			</xsl:when>
			<xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
		  </xsl:choose>
		</xsl:when>
		<xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
	  </xsl:choose>
	</xsl:template>

<!-- after-last: return substring after the final occurrence of a delimiter -->
<xsl:template name="after-last">
  <xsl:param name="s"/>
  <xsl:param name="delim" select="'|'"/>
  <xsl:choose>
    <xsl:when test="contains($s,$delim)">
      <xsl:call-template name="after-last">
        <xsl:with-param name="s" select="substring-after($s,$delim)"/>
        <xsl:with-param name="delim" select="$delim"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- drop-trailing-digits: recursively remove trailing tokens that are numbers (optionally signed) -->
<xsl:template name="drop-trailing-digits">
  <xsl:param name="s"/>
  <xsl:param name="delim" select="'|'"/>
  <xsl:variable name="last">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$s"/>
      <xsl:with-param name="delim" select="$delim"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:choose>
    <!-- numeric if removing digits and a leading '-' leaves empty -->
    <xsl:when test="translate($last,'-0123456789','')='' and contains($s,$delim)">
      <xsl:call-template name="drop-trailing-digits">
        <xsl:with-param name="s" select="substring-before($s, concat($delim,$last))"/>
        <xsl:with-param name="delim" select="$delim"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$s"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- format-DBSignal: compact label from a raw Vector DBSignal path -->
<xsl:template name="format-DBSignal">
  <xsl:param name="raw"/>

  <!-- trim BEGIN markers anywhere -->
  <xsl:variable name="noBegin">
    <xsl:call-template name="strip-begin-markers">
      <xsl:with-param name="s" select="normalize-space($raw)"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- cut at END_OF_OBJECT -->
  <xsl:variable name="preEnd"
    select="substring-before(concat($noBegin,'|END_OF_OBJECT'),'|END_OF_OBJECT')"/>

  <!-- drop leading pure-digit tokens like "1|" -->
  <xsl:variable name="core0">
    <xsl:call-template name="drop-leading-digits">
      <xsl:with-param name="s" select="$preEnd"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- drop a leading 'DBSignal*' token if present -->
  <xsl:variable name="h0" select="substring-before(concat($core0,'|'),'|')"/>
  <xsl:variable name="t0" select="substring-after($core0,'|')"/>
  <xsl:variable name="core1">
    <xsl:choose>
      <xsl:when test="starts-with($h0,'DBSignal')"><xsl:value-of select="$t0"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$core0"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- drop a leading 'NodeOrFrameData*' token if present -->
  <xsl:variable name="h1" select="substring-before(concat($core1,'|'),'|')"/>
  <xsl:variable name="t1" select="substring-after($core1,'|')"/>
  <xsl:variable name="core2">
    <xsl:choose>
      <xsl:when test="starts-with($h1,'NodeOrFrameData')"><xsl:value-of select="$t1"/></xsl:when>
      <xsl:otherwise><xsl:value-of select="$core1"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- remove trailing flag if it is 0 / 1 / TRUE / FALSE -->
  <xsl:variable name="last1">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$core2"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="core">
    <xsl:choose>
      <xsl:when test="translate($last1,'truefalse','TRUEFALSE')='TRUE'
                      or translate($last1,'truefalse','TRUEFALSE')='FALSE'
                      or $last1='0' or $last1='1'">
        <xsl:value-of select="substring-before($core2, concat('|',$last1))"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$core2"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- signal = last token; pdu = token before that -->
  <xsl:variable name="sig">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$core"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="preSig" select="substring-before($core, concat('|',$sig))"/>
  <xsl:variable name="pdu">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$preSig"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- print -->
  <xsl:choose>
    <xsl:when test="normalize-space($pdu)!='' and normalize-space($sig)!=''">
      <xsl:text>DBSignal </xsl:text>
      <xsl:value-of select="$pdu"/><xsl:text>.</xsl:text><xsl:value-of select="$sig"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$raw"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>


<!-- diagServiceLabel: extract a readable name from a DiaObj path -->
<xsl:template name="diagServiceLabel">
  <xsl:param name="path"/>
  <!-- Trim trailing END_OF_OBJECT marker if present -->
  <xsl:variable name="base"
    select="substring-before(concat($path,'|END_OF_OBJECT'), '|END_OF_OBJECT')"/>
  <!-- Prefer token after '|DIDs|' if available; otherwise last segment -->
  <xsl:variable name="afterDIDs" select="substring-after($base,'|DIDs|')"/>
  <xsl:choose>
    <xsl:when test="$afterDIDs!=''">
      <xsl:value-of select="substring-before(concat($afterDIDs,'|'),'|')"/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:call-template name="after-last">
        <xsl:with-param name="s"     select="$base"/>
        <xsl:with-param name="delim" select="'|'"/>
      </xsl:call-template>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>






<!-- Pretty-print DBSignal as: DBSignal <PDU>.<Signal>
     Robust against trailing flags and numeric tokens. -->
<xsl:template name="prettyDbSignal">
  <xsl:param name="text"/>
  <xsl:variable name="raw" select="normalize-space($text)"/>

  <!-- Signal = first token after END_OF_OBJECT_FrameData| -->
  <xsl:variable name="sigSrc" select="substring-after($raw,'|END_OF_OBJECT_FrameData|')"/>
  <xsl:variable name="sig">
    <xsl:choose>
      <xsl:when test="string-length($sigSrc) &gt; 0">
        <xsl:value-of select="substring-before(concat($sigSrc,'|'),'|')"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:call-template name="after-last">
          <xsl:with-param name="s" select="$raw"/>
        </xsl:call-template>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- Everything *before* END_OF_OBJECT_FrameData -->
  <xsl:variable name="pre" select="substring-before($raw,'|END_OF_OBJECT_FrameData|')"/>

  <!-- helpers for case handling -->
  <xsl:variable name="AZ" select="'ABCDEFGHIJKLMNOPQRSTUVWXYZ'"/>
  <xsl:variable name="az" select="'abcdefghijklmnopqrstuvwxyz'"/>

  <!-- trim last token if it is a flag (0/1/TRUE/FALSE) -->
  <xsl:variable name="t1">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$pre"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="pre1">
    <xsl:choose>
      <xsl:when test="$t1='0' or $t1='1' or
                      translate($t1,$az,$AZ)='TRUE' or translate($t1,$az,$AZ)='FALSE'">
        <xsl:value-of select="substring-before($pre, concat('|',$t1))"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$pre"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- trim a second trailing flag if present -->
  <xsl:variable name="t2">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$pre1"/>
    </xsl:call-template>
  </xsl:variable>
  <xsl:variable name="pre2">
    <xsl:choose>
      <xsl:when test="$t2='0' or $t2='1' or
                      translate($t2,$az,$AZ)='TRUE' or translate($t2,$az,$AZ)='FALSE'">
        <xsl:value-of select="substring-before($pre1, concat('|',$t2))"/>
      </xsl:when>
      <xsl:otherwise><xsl:value-of select="$pre1"/></xsl:otherwise>
    </xsl:choose>
  </xsl:variable>

  <!-- PDU = last token of trimmed pre2 -->
  <xsl:variable name="pdu">
    <xsl:call-template name="after-last">
      <xsl:with-param name="s" select="$pre2"/>
    </xsl:call-template>
  </xsl:variable>

  <!-- Render: prefer "<PDU>.<Signal>", else just "<Signal>" -->
  <xsl:variable name="pduU" select="translate(normalize-space($pdu),$az,$AZ)"/>
  <xsl:choose>
    <xsl:when test="normalize-space($pdu)!='' and
                    not($pduU='0' or $pduU='1' or $pduU='TRUE' or $pduU='FALSE') and
                    not(number($pdu)=number($pdu))">
      <xsl:text>DBSignal </xsl:text>
      <xsl:value-of select="normalize-space($pdu)"/><xsl:text>.</xsl:text>
      <xsl:value-of select="normalize-space($sig)"/>
    </xsl:when>
    <xsl:when test="normalize-space($sig)!=''">
      <xsl:text>DBSignal </xsl:text><xsl:value-of select="normalize-space($sig)"/>
    </xsl:when>
    <xsl:otherwise><xsl:value-of select="$raw"/></xsl:otherwise>
  </xsl:choose>
</xsl:template>

<!-- lastAlphaToken: walk a '|' separated string and keep the last token
     that contains a letter (and is not TRUE/FALSE). Returns '' if none. -->
<xsl:template name="lastAlphaToken">
  <xsl:param name="s"/>
  <xsl:param name="best" select="''"/>
  <xsl:choose>
    <xsl:when test="contains($s,'|')">
      <xsl:variable name="tok"  select="substring-before($s,'|')"/>
      <xsl:variable name="rest" select="substring-after($s,'|')"/>
      <!-- token contains at least one A–Z/a–z ? -->
      <xsl:variable name="hasAlpha"
        select="string-length($tok) &gt; string-length(translate($tok,
                 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz',''))"/>
      <xsl:variable name="tokU"
        select="translate($tok,'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')"/>
      <xsl:choose>
        <xsl:when test="$hasAlpha and not($tokU='TRUE' or $tokU='FALSE')">
          <xsl:call-template name="lastAlphaToken">
            <xsl:with-param name="s"    select="$rest"/>
            <xsl:with-param name="best" select="$tok"/>
          </xsl:call-template>
        </xsl:when>
        <xsl:otherwise>
          <xsl:call-template name="lastAlphaToken">
            <xsl:with-param name="s"    select="$rest"/>
            <xsl:with-param name="best" select="$best"/>
          </xsl:call-template>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$best"/>
    </xsl:otherwise>
  </xsl:choose>
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

<!-- Do not render boolean <active> flags as steps -->
<xsl:template match="tt:active | *[local-name()='active']" mode="step"/>


	<!-- SET (namespace-agnostic, with prettyPath + bestValueLabel) -->
	<xsl:template match="tt:set | *[local-name()='set']" mode="step">
	  <li>
		<code>SET</code>
		<ul>
		  <xsl:for-each select="*[local-name()='in']/*[local-name()='assignment']">
			<li>
			  <code>
				<!-- LHS: sink path, pretty-printed -->
				<xsl:call-template name="prettyPath">
				  <xsl:with-param name="text"
					select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
				</xsl:call-template>

				<xsl:text> = </xsl:text>

				<!-- RHS: prefer value (const/variable), else dbobject path, else raw -->
				<xsl:choose>
				  <!-- value (const/variable) -->
				  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value'])!=''">
					<xsl:call-template name="bestValueLabel">
					  <xsl:with-param name="ctx" select="*[local-name()='source']/*[local-name()='value']"/>
					</xsl:call-template>
				  </xsl:when>

				  <!-- another object -->
				  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])!=''">
					<xsl:call-template name="prettyPath">
					  <xsl:with-param name="text"
						select="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])"/>
					</xsl:call-template>
				  </xsl:when>

				  <!-- fallback -->
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

	<!-- STATECHANGE (namespace-agnostic): IN / WAIT / EXPECTED with prettyPath -->

<!-- STATECHANGE (namespace-agnostic): IN / WAIT / EXPECTED with prettyPath -->
<xsl:template match="tt:statechange | *[local-name()='statechange']" mode="step">
  <li>
    <code>STATECHANGE</code>
    <ul>

      <!-- IN -->
      <li><em>IN</em>
        <ul>
          <!-- Typical shape: <in><assignment>… -->
          <xsl:for-each select="(tt:in | *[local-name()='in'])/*[local-name()='assignment']">
            <li>
              <code>
                <!-- LHS -->
                <xsl:call-template name="prettyPath">
                  <xsl:with-param name="text"
                    select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
                </xsl:call-template>
                <xsl:text> = </xsl:text>
                <!-- RHS: const/var -> bestValueLabel; dbobject -> prettyPath; fallback raw -->
                <xsl:choose>
                  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value'])!=''">
                    <xsl:call-template name="bestValueLabel">
                      <xsl:with-param name="ctx" select="*[local-name()='source']/*[local-name()='value']"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])!=''">
                    <xsl:call-template name="prettyPath">
                      <xsl:with-param name="text"
                        select="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:value-of select="normalize-space(*[local-name()='source'])"/>
                  </xsl:otherwise>
                </xsl:choose>
              </code>
            </li>
          </xsl:for-each>

          <!-- If authors put compares inside <in>, render them too -->
          <xsl:apply-templates select="(tt:in | *[local-name()='in'])/*[local-name()='compare']" mode="step"/>
        </ul>
      </li>

      <!-- WAIT / TIMEOUT: list any descendant waits/timeouts -->
      <xsl:variable name="waitNodes" select=".//*[local-name()='wait' or local-name()='timeout']"/>
      <xsl:if test="$waitNodes">
        <li><em>WAIT</em>
          <ul>
            <xsl:for-each select="$waitNodes">
              <!-- choose a base node that has value/unit underneath -->
              <xsl:variable name="base"
                select="(.//*[local-name()='time' or local-name()='timeout'] | self::node())[1]"/>
              <xsl:call-template name="emit-wait-line">
                <xsl:with-param name="base" select="$base"/>
              </xsl:call-template>
            </xsl:for-each>
          </ul>
        </li>
      </xsl:if>

      <!-- EXPECTED -->
      <li><em>EXPECTED</em>
        <ul>
          <!-- Comparisons -->
          <xsl:apply-templates select="(tt:expected | *[local-name()='expected'])/*[local-name()='compare']" mode="step"/>

          <!-- Assignments (lhs = rhs) -->
          <xsl:for-each select="(tt:expected | *[local-name()='expected'])/*[local-name()='assignment']">
            <li>
              <code>
                <xsl:call-template name="prettyPath">
                  <xsl:with-param name="text"
                    select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
                </xsl:call-template>
                <xsl:text> = </xsl:text>
                <xsl:choose>
                  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value'])!=''">
                    <xsl:call-template name="bestValueLabel">
                      <xsl:with-param name="ctx" select="*[local-name()='source']/*[local-name()='value']"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])!=''">
                    <xsl:call-template name="prettyPath">
                      <xsl:with-param name="text"
                        select="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])"/>
                    </xsl:call-template>
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

    </ul>
  </li>
</xsl:template>



	
	
	<!-- STATECHECK: show optional TITLE + EXPECTED (comparisons/assignments) -->
	<xsl:template match="tt:statecheck | *[local-name()='statecheck']" mode="step">
	  <li>
		<code>STATECHECK</code>
		<ul>
		  <!-- Optional title/name -->
		  <xsl:variable name="ttl"
			select="normalize-space( (tt:title | *[local-name()='title'] | tt:name | *[local-name()='name'])[1] )"/>
		  <xsl:if test="$ttl!=''">
			<li><em>TITLE:</em> <span class="muted"><xsl:value-of select="$ttl"/></span></li>
		  </xsl:if>

		  <!-- EXPECTED -->
		  <li><em>EXPECTED</em>
			<ul>
			  <xsl:choose>
				<!-- Canonical shape: everything wrapped in <expected> -->
				<xsl:when test="(tt:expected | *[local-name()='expected'])">
				  <!-- comparisons -->
				  <xsl:apply-templates
					select="(tt:expected | *[local-name()='expected'])/*[local-name()='compare']"
					mode="step"/>

				  <!-- assignments (lhs = rhs) -->
				  <xsl:for-each
					select="(tt:expected | *[local-name()='expected'])/*[local-name()='assignment']">
					<li>
					  <code>
						<xsl:call-template name="prettyPath">
						  <xsl:with-param name="text"
							select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
						</xsl:call-template>
						<xsl:text> = </xsl:text>
						<xsl:choose>
						  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value'])!=''">
							<xsl:call-template name="bestValueLabel">
							  <xsl:with-param name="ctx" select="*[local-name()='source']/*[local-name()='value']"/>
							</xsl:call-template>
						  </xsl:when>
						  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])!=''">
							<xsl:call-template name="prettyPath">
							  <xsl:with-param name="text"
								select="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])"/>
							</xsl:call-template>
						  </xsl:when>
						  <xsl:otherwise>
							<xsl:value-of select="normalize-space(*[local-name()='source'])"/>
						  </xsl:otherwise>
						</xsl:choose>
					  </code>
					</li>
				  </xsl:for-each>
				</xsl:when>

				<!-- Some projects put items directly under <statecheck> -->
				<xsl:otherwise>
				  <xsl:apply-templates select="*[local-name()='compare']" mode="step"/>

				  <xsl:for-each select="*[local-name()='assignment']">
					<li>
					  <code>
						<xsl:call-template name="prettyPath">
						  <xsl:with-param name="text"
							select="normalize-space(*[local-name()='sink']/*[local-name()='dbobject'])"/>
						</xsl:call-template>
						<xsl:text> = </xsl:text>
						<xsl:choose>
						  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='value'])!=''">
							<xsl:call-template name="bestValueLabel">
							  <xsl:with-param name="ctx" select="*[local-name()='source']/*[local-name()='value']"/>
							</xsl:call-template>
						  </xsl:when>
						  <xsl:when test="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])!=''">
							<xsl:call-template name="prettyPath">
							  <xsl:with-param name="text"
								select="normalize-space(*[local-name()='source']/*[local-name()='dbobject'])"/>
							</xsl:call-template>
						  </xsl:when>
						  <xsl:otherwise>
							<xsl:value-of select="normalize-space(*[local-name()='source'])"/>
						  </xsl:otherwise>
						</xsl:choose>
					  </code>
					</li>
				  </xsl:for-each>
				</xsl:otherwise>
			  </xsl:choose>
			</ul>
		  </li>
		</ul>
	  </li>
	</xsl:template>

  
  <xsl:template match="tt:statecheck/tt:expected" mode="step">
    <li><strong>EXPECTED</strong><ul><xsl:apply-templates select="tt:*" mode="step"/></ul></li>
  </xsl:template>

  <!-- ===== Comparisons (==, !=, >, >=, <, <=) with prettyPath + bestValueLabel ===== -->
	<xsl:template match="tt:compare | *[local-name()='compare']" mode="step">
	  <!-- operator node and printable symbol -->
	  <xsl:variable name="opNode"
		select=".//*[local-name()='eq' or local-name()='ne' or local-name()='gt' or local-name()='ge' or local-name()='lt' or local-name()='le'][1]"/>
	  <xsl:variable name="op">
		<xsl:choose>
		  <xsl:when test="local-name($opNode)='eq'">==</xsl:when>
		  <xsl:when test="local-name($opNode)='ne'">!=</xsl:when>
		  <xsl:when test="local-name($opNode)='gt'">&gt;</xsl:when>
		  <xsl:when test="local-name($opNode)='ge'">&gt;=</xsl:when>
		  <xsl:when test="local-name($opNode)='lt'">&lt;</xsl:when>
		  <xsl:when test="local-name($opNode)='le'">&lt;=</xsl:when>
		  <xsl:otherwise>==</xsl:otherwise>
		</xsl:choose>
	  </xsl:variable>

	  <!-- LHS: prefer explicit left/lhs dbobject; else first dbobject -->
	  <xsl:variable name="lhsDb"
		select="(./*[local-name()='left']//*[local-name()='dbobject']
				| ./*[local-name()='lhs']//*[local-name()='dbobject']
				| .//*[local-name()='dbobject'])[1]"/>

	  <!-- RHS unit (if any) -->
	  <xsl:variable name="rhsUnit" select="normalize-space(($opNode//*[local-name()='unit'])[1])"/>

	  <!-- RHS value display: valuetable -> value; value(const/var) -> bestValueLabel; dbobject -> prettyPath; else raw -->
	  <xsl:variable name="rhsDisplay">
		<xsl:choose>
		  <!-- valuetable entry -->
		  <xsl:when test="normalize-space(($opNode/*[local-name()='valuetable_entry'])[1])!=''">
			<xsl:value-of select="normalize-space(($opNode/*[local-name()='valuetable_entry'])[1])"/>
		  </xsl:when>
		  <!-- const/variable -->
		  <xsl:when test="($opNode/*[local-name()='value'])[1]">
			<xsl:call-template name="bestValueLabel">
			  <xsl:with-param name="ctx" select="($opNode/*[local-name()='value'])[1]"/>
			</xsl:call-template>
		  </xsl:when>
		  <!-- another object on RHS -->
		  <xsl:when test="normalize-space(($opNode/*[local-name()='dbobject'])[1])!=''">
			<xsl:call-template name="prettyPath">
			  <xsl:with-param name="text" select="normalize-space(($opNode/*[local-name()='dbobject'])[1])"/>
			</xsl:call-template>
		  </xsl:when>
		  <!-- raw fallback (text inside op node) -->
		  <xsl:otherwise>
			<xsl:value-of select="normalize-space(string($opNode))"/>
		  </xsl:otherwise>
		</xsl:choose>
  </xsl:variable>

  <li>
    <code>
      <!-- LHS pretty -->
      <xsl:call-template name="prettyPath">
        <xsl:with-param name="text" select="normalize-space(string($lhsDb))"/>
      </xsl:call-template>
      <xsl:text> </xsl:text>
      <xsl:value-of select="$op"/>
      <xsl:text> </xsl:text>
      <xsl:value-of select="$rhsDisplay"/>
      <xsl:if test="$rhsUnit!=''">
        <xsl:text> </xsl:text><xsl:value-of select="$rhsUnit"/>
      </xsl:if>
    </code>
  </li>
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

<!-- OCCURRENCE_COUNT: title/limits/join + watched objects (pretty-printed) -->
<xsl:template match="tt:occurrence_count | *[local-name()='occurrence_count']" mode="step">
  <li>
	<code>OCCURRENCE_COUNT</code>

	<!-- Optional title/name -->
	<xsl:variable name="tTitle" select="normalize-space( (tt:title | *[local-name()='title'] | tt:name | *[local-name()='name'])[1] )"/>
	<xsl:if test="$tTitle!=''">
	  <span class="muted"> — <xsl:value-of select="$tTitle"/></span>
	</xsl:if>

	<ul>
	  <!-- limits: min / max / timeout (robust + variable-aware) -->
	  <xsl:variable name="minNode" select="(tt:mincount | *[local-name()='mincount'])[1]"/>
	  <xsl:variable name="maxNode" select="(tt:maxcount | *[local-name()='maxcount'])[1]"/>
	  <xsl:variable name="toNode"  select="(tt:timeout  | *[local-name()='timeout'])[1]"/>

	  <xsl:if test="$minNode or $maxNode or $toNode">
		<li class="muted">
		  <xsl:text>limits: </xsl:text>

		  <!-- min -->
		  <xsl:if test="$minNode">
			<xsl:text>min=</xsl:text><code>
			  <xsl:choose>
				<xsl:when test="normalize-space($minNode//*[local-name()='const'][1])!=''">
				  <xsl:value-of select="normalize-space($minNode//*[local-name()='const'][1])"/>
				</xsl:when>
				<xsl:when test="$minNode//*[local-name()='value'][1]">
				  <xsl:call-template name="bestValueLabel">
					<xsl:with-param name="ctx" select="$minNode//*[local-name()='value'][1]"/>
				  </xsl:call-template>
				</xsl:when>
				<xsl:otherwise>
				  <xsl:value-of select="normalize-space(string($minNode))"/>
				</xsl:otherwise>
			  </xsl:choose>
			</code>
		  </xsl:if>

		  <!-- separators -->
		  <xsl:if test="$minNode and ($maxNode or $toNode)"><xsl:text>; </xsl:text></xsl:if>

		  <!-- max -->
		  <xsl:if test="$maxNode">
			<xsl:text>max=</xsl:text><code>
			  <xsl:choose>
				<xsl:when test="normalize-space($maxNode//*[local-name()='const'][1])!=''">
				  <xsl:value-of select="normalize-space($maxNode//*[local-name()='const'][1])"/>
				</xsl:when>
				<xsl:when test="$maxNode//*[local-name()='value'][1]">
				  <xsl:call-template name="bestValueLabel">
					<xsl:with-param name="ctx" select="$maxNode//*[local-name()='value'][1]"/>
				  </xsl:call-template>
				</xsl:when>
				<xsl:otherwise>
				  <xsl:value-of select="normalize-space(string($maxNode))"/>
				</xsl:otherwise>
			  </xsl:choose>
			</code>
		  </xsl:if>

		  <xsl:if test="$maxNode and $toNode"><xsl:text>; </xsl:text></xsl:if>

		  <!-- timeout -->
		  <xsl:if test="$toNode">
			<xsl:text>timeout=</xsl:text><code>
			  <xsl:choose>
				<xsl:when test="normalize-space($toNode//*[local-name()='const'][1])!=''">
				  <xsl:value-of select="normalize-space($toNode//*[local-name()='const'][1])"/>
				</xsl:when>
				<xsl:when test="$toNode//*[local-name()='value'][1]">
				  <xsl:call-template name="bestValueLabel">
					<xsl:with-param name="ctx" select="$toNode//*[local-name()='value'][1]"/>
				  </xsl:call-template>
				</xsl:when>
				<xsl:otherwise>
				  <xsl:value-of select="normalize-space(string($toNode))"/>
				</xsl:otherwise>
			  </xsl:choose>
			  <!-- guaranteed space before unit -->
			  <xsl:variable name="tUnit" select="normalize-space(($toNode//*[local-name()='unit'])[1])"/>
			  <xsl:if test="$tUnit!=''"><xsl:text> </xsl:text><xsl:value-of select="$tUnit"/></xsl:if>
			</code>
		  </xsl:if>
		</li>
	  </xsl:if>

	  <!-- Optional join condition (e.g., AND/OR) -->
	  <xsl:variable name="join" select="normalize-space( (tt:joincondition | *[local-name()='joincondition'])[1] )"/>
	  <xsl:if test="$join!=''">
		<li class="muted">join=<code><xsl:value-of select="$join"/></code></li>
	  </xsl:if>


		<!-- Watched objects: prefer explicit dbobject; fallback to node string-value -->
		<xsl:for-each select="(tt:objects | *[local-name()='objects'])[1]/*">
		  <li>
			<code>
			  <xsl:variable name="raw"
				select="normalize-space( (./tt:dbobject | ./*[local-name()='dbobject'] | .)[1] )"/>
			  <xsl:choose>
				<!-- PDU: compact label -->
				<xsl:when test="local-name(.)='pdu' or contains($raw,'DBFrameOrPDU')">
				  <xsl:text>PDU </xsl:text>
				  <xsl:call-template name="pduLabel">
					<xsl:with-param name="path" select="$raw"/>
				  </xsl:call-template>
				</xsl:when>
				<!-- Everything else -->
				<xsl:otherwise>
				  <xsl:text>OBJ </xsl:text>
				  <xsl:call-template name="prettyPath">
					<xsl:with-param name="text" select="$raw"/>
				  </xsl:call-template>
				</xsl:otherwise>
			  </xsl:choose>
			</code>
		  </li>
		</xsl:for-each>

	</ul>
  </li>
</xsl:template>


	<!-- CHECK_DEACTIVATION: stop a named/ID'd monitor or the most recent; show referenced objects -->
	<xsl:template match="tt:check_deactivation | *[local-name()='check_deactivation']" mode="step">
	  <li>
		<code>CHECK_DEACTIVATION</code>

		<!-- Prefer id/checkid (element or attribute), then title/name, else fallback -->
		<xsl:variable name="cid"
		  select="normalize-space( (tt:checkid | @checkid | @id | *[local-name()='checkid'] | @*[local-name()='checkid'] | @*[local-name()='id'])[1] )"/>
		<xsl:variable name="ttl"
		  select="normalize-space( (tt:title | *[local-name()='title'] | tt:name | *[local-name()='name'])[1] )"/>

		<xsl:choose>
		  <xsl:when test="$cid!=''">
			<span class="muted"> — id=<code><xsl:value-of select="$cid"/></code></span>
		  </xsl:when>
		  <xsl:when test="$ttl!=''">
			<span class="muted"> — <xsl:value-of select="$ttl"/></span>
		  </xsl:when>
		  <xsl:otherwise>
			<span class="muted"> — deactivate last started</span>
		  </xsl:otherwise>
		</xsl:choose>

		<!-- If there are referenced objects, list them -->
		<xsl:variable name="objs"
		  select=".//*[local-name()='objects']/* | .//*[local-name()='pdu' or local-name()='dbobject' or local-name()='eventsource']"/>

		<xsl:if test="$objs">
		  <ul>
			<xsl:for-each select="$objs">
			  <li>
				<code>
				  <xsl:choose>
					<xsl:when test="local-name(.)='pdu'">PDU </xsl:when>
					<xsl:when test="local-name(.)='eventsource'">SRC </xsl:when>
					<xsl:otherwise>OBJ </xsl:otherwise>
				  </xsl:choose>
				  <xsl:call-template name="prettyPath">
					<xsl:with-param name="text"
					  select="normalize-space( (./tt:dbobject | ./*[local-name()='dbobject'] | .)[1] )"/>
				  </xsl:call-template>
				</code>
			  </li>
			</xsl:for-each>
		  </ul>
		</xsl:if>
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

<!-- NOVALUECHANGE: robust listing with pretty fallback -->
<xsl:template match="tt:novaluechange | *[local-name()='novaluechange']" mode="step">
  <li>
    <code>NOVALUECHANGE</code>
    <!-- optional caption/title -->
    <xsl:variable name="tTitle"
      select="normalize-space( (tt:title | *[local-name()='title'])[1] )"/>
    <xsl:if test="$tTitle!=''">
      <span class="muted"> — <xsl:value-of select="$tTitle"/></span>
    </xsl:if>

    <!-- gather any explicit objects or dbobject paths under this node -->
    <xsl:variable name="candidates"
      select=".//*[local-name()='objects']/* | .//*[local-name()='dbobject']"/>

    <ul>
      <xsl:choose>
        <xsl:when test="count($candidates) &gt; 0">
          <xsl:for-each select="$candidates">
            <li>
              <code>
                <xsl:variable name="raw" select="normalize-space(string(.))"/>
                <xsl:choose>
                  <!-- try to pretty-print, fallback to raw -->
                  <xsl:when test="$raw!=''">
                    <xsl:call-template name="prettyPath">
                      <xsl:with-param name="text" select="$raw"/>
                    </xsl:call-template>
                  </xsl:when>
                  <xsl:otherwise>
                    <xsl:text>(empty path)</xsl:text>
                  </xsl:otherwise>
                </xsl:choose>
              </code>
            </li>
          </xsl:for-each>
        </xsl:when>
        <xsl:otherwise>
          <li class="muted">no explicit object list in VTT</li>
        </xsl:otherwise>
      </xsl:choose>
    </ul>
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


<!-- DIAGSERVICE: show service name; note request/response presence -->
<xsl:template match="tt:diagservice | *[local-name()='diagservice']" mode="step">
  <li>
    <code>DIAGSERVICE</code>
    <xsl:variable name="svc" select="normalize-space((tt:service | *[local-name()='service'])[1])"/>
    <xsl:text> — </xsl:text>
    <xsl:choose>
      <xsl:when test="$svc!=''">
        <code>
          <xsl:call-template name="diagServiceLabel">
            <xsl:with-param name="path" select="$svc"/>
          </xsl:call-template>
        </code>
      </xsl:when>
      <xsl:otherwise><span class="muted">no service specified</span></xsl:otherwise>
    </xsl:choose>
    <ul>
      <xsl:if test="*[local-name()='diagrequest']"><li class="muted">request present</li></xsl:if>
      <xsl:if test="*[local-name()='diagresponse']"><li class="muted">response present</li></xsl:if>
    </ul>
  </li>
</xsl:template>


<!-- NETFUNCTION: name + first const argument; show class if present -->
<xsl:template match="tt:netfunction | *[local-name()='netfunction']" mode="step">
  <li>
    <code>NETFUNC </code>
    <code><xsl:value-of select="normalize-space((tt:name | *[local-name()='name'])[1])"/></code>
    <xsl:variable name="arg"
      select="normalize-space((tt:param/*[local-name()='value']/*[local-name()='const'])[1])"/>
    <xsl:if test="$arg!=''"><code>(<xsl:value-of select="$arg"/>)</code></xsl:if>
    <xsl:variable name="klass" select="normalize-space((tt:class | *[local-name()='class'])[1])"/>
    <xsl:if test="$klass!=''">
      <span class="muted"> — class=<code><xsl:value-of select="$klass"/></code></span>
    </xsl:if>
  </li>
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
