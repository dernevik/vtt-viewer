<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="urn:vttx:v0.1" exclude-result-prefixes="v">
    <xsl:output method="html" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- ===== params / case helpers ===== -->
    <xsl:param name="fixture"/>
    <xsl:variable name="AZ">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="az">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <!-- ===== small helpers ===== -->
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
            <xsl:otherwise>
                <xsl:value-of select="$s"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template name="prettyPath">
        <xsl:param name="raw"/>
        <xsl:variable name="r" select="normalize-space($raw)"/>
        <xsl:variable name="label">
            <xsl:choose>
                <xsl:when test="contains($r,'_BEGIN_OF_OBJECT|')">
                    <xsl:value-of select="substring-before(substring-after($r,'_BEGIN_OF_OBJECT|'),'|END_OF_OBJECT')"/>
                </xsl:when>
                <xsl:when test="contains($r,'|')">
                    <xsl:call-template name="after-last">
                        <xsl:with-param name="s" select="$r"/>
                    </xsl:call-template>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:value-of select="$r"/>
                </xsl:otherwise>
            </xsl:choose>
        </xsl:variable>
        <xsl:value-of select="normalize-space($label)"/>
    </xsl:template>
    <!-- Build LHS label for NEW extractor shape -->
    <xsl:template name="lhsLabel">
        <xsl:param name="lhs" select="v:lhs"/>
        <xsl:variable name="kind" select="translate(normalize-space($lhs/@kind), $az, $AZ)"/>
        <xsl:choose>
            <!-- DBSignal: prefer PDU.signal if both present -->
            <xsl:when test="$kind='DBSIGNAL' and normalize-space($lhs/@pdu)!='' and normalize-space($lhs/@signal)!=''">
                <xsl:text>DBSignal </xsl:text>
                <xsl:value-of select="concat($lhs/@pdu,'.',$lhs/@signal)"/>
            </xsl:when>
            <!-- SysVar or PDU with friendly label -->
            <xsl:when test="($kind='SYSVAR' or $kind='PDU') and normalize-space($lhs/v:label)!=''">
                <xsl:value-of select="$kind"/>
                <xsl:text> </xsl:text>
                <xsl:value-of select="normalize-space($lhs/v:label)"/>
            </xsl:when>
            <!-- Fallbacks: label, then raw path -->
            <xsl:when test="normalize-space($lhs/v:label)!=''">
                <xsl:value-of select="normalize-space($lhs/v:label)"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="normalize-space($lhs/@raw)"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- RHS for NEW extractor shape -->
    <xsl:template name="renderRhs">
        <xsl:param name="rhs" select="v:rhs"/>
        <xsl:choose>
            <xsl:when test="normalize-space($rhs/@value)!=''">
                <xsl:value-of select="$rhs/@value"/>
            </xsl:when>
            <xsl:otherwise>?</xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- ===== ROOT ===== -->
    <xsl:template match="/">
        <html>
            <head>
                <meta charset="utf-8"/>
                <title>
                    <xsl:choose>
                        <xsl:when test="normalize-space($fixture)!=''">Fixture: <xsl:value-of select="$fixture"/>
                        </xsl:when>
                        <xsl:otherwise>Test Listing</xsl:otherwise>
                    </xsl:choose>
                </title>
                <style>
          body{font-family:Segoe UI,Arial,sans-serif;line-height:1.4;padding:1rem;}
          code{background:#f6f8fa;padding:0 .25rem;border-radius:.25rem}
          ul{margin:.25rem 0 .75rem 1.25rem}
          .muted{color:#666}
          h2{margin-top:1.25rem}
        </style>
            </head>
            <body>
                <xsl:variable name="fx" select="normalize-space($fixture)"/>
                <xsl:variable name="fxU" select="translate($fx,$az,$AZ)"/>
                <xsl:choose>
                    <xsl:when test="$fx=''">
                        <xsl:apply-templates select="v:vttx/v:fixture"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:variable name="targets" select="v:vttx//v:fixture[translate(normalize-space(@title),$az,$AZ)=$fxU]"/>
                        <xsl:choose>
                            <xsl:when test="count($targets)&gt;0">
                                <xsl:apply-templates select="$targets"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <p class="muted">No fixture titled "<code>
                                        <xsl:value-of select="$fixture"/>
                                    </code>" found.</p>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:otherwise>
                </xsl:choose>
            </body>
        </html>
    </xsl:template>
    <!-- ===== FIXTURE (recursive) ===== -->
    <xsl:template match="v:fixture">
        <h2>Fixture: <xsl:value-of select="@title"/>
        </h2>
        <xsl:if test="v:tc">
            <ul>
                <xsl:apply-templates select="v:tc"/>
            </ul>
        </xsl:if>
        <xsl:apply-templates select="v:fixture"/>
        <xsl:if test="not(v:tc) and not(v:fixture)">
            <p class="muted">(no test cases)</p>
        </xsl:if>
    </xsl:template>
    <!-- ===== TEST CASE ===== -->
    <xsl:template match="v:tc">
        <h3>TestCase: <xsl:value-of select="@title"/>
        </h3>
        <ul>
            <xsl:if test="v:prep/*">
                <li>
                    <strong>Preparation</strong>
                    <ul>
                        <xsl:apply-templates select="v:prep/*"/>
                    </ul>
                </li>
            </xsl:if>
            <xsl:if test="v:body/*">
                <li>
                    <strong>Steps</strong>
                    <ul>
                        <xsl:apply-templates select="v:body/*"/>
                    </ul>
                </li>
            </xsl:if>
            <xsl:if test="v:comp/*">
                <li>
                    <strong>Completion</strong>
                    <ul>
                        <xsl:apply-templates select="v:comp/*"/>
                    </ul>
                </li>
            </xsl:if>
        </ul>
    </xsl:template>
    <!-- ===== STEP RENDERERS ===== -->
    <!-- WAIT -->
    <xsl:template match="v:wait">
        <li>
            <code>WAIT <xsl:choose>
                    <xsl:when test="normalize-space(v:ms)!=''">
                        <xsl:value-of select="v:ms"/>
                        <xsl:text> ms</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="normalize-space(v:label)"/>
                        <xsl:if test="normalize-space(v:unit)!=''">
                            <xsl:text> </xsl:text>
                            <xsl:value-of select="v:unit"/>
                        </xsl:if>
                    </xsl:otherwise>
                </xsl:choose>
            </code>
        </li>
    </xsl:template>
    <!-- NETFUNC -->
    <xsl:template match="v:netfunc">
        <li>
            <code>NETFUNC <xsl:value-of select="@name"/>(<xsl:for-each select="v:param">
                    <xsl:if test="position()&gt;1">, </xsl:if>
                    <xsl:choose>
                        <xsl:when test="@type='String'">"<xsl:value-of select="v:value"/>"</xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="v:value"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>) — class=<xsl:value-of select="@class"/>
            </code>
        </li>
    </xsl:template>
    <!-- SET (supports NEW and OLD shapes) -->
    <xsl:template match="v:set">
        <li>
            <strong>SET</strong>
            <ul>
                <xsl:choose>
                    <xsl:when test="v:assign">
                        <xsl:apply-templates select="v:assign"/>
                    </xsl:when>
                    <xsl:when test="v:assignment">
                        <xsl:apply-templates select="v:assignment"/>
                    </xsl:when>
                    <xsl:otherwise>
                        <li class="muted">
                            <code>(no assignments)</code>
                        </li>
                    </xsl:otherwise>
                </xsl:choose>
            </ul>
        </li>
    </xsl:template>
    <!-- NEW shape: one assignment line -->
    <xsl:template match="v:assign">
        <li>
            <code>
                <xsl:call-template name="lhsLabel">
                    <xsl:with-param name="lhs" select="v:lhs"/>
                </xsl:call-template>
                <xsl:text> = </xsl:text>
                <xsl:call-template name="renderRhs">
                    <xsl:with-param name="rhs" select="v:rhs"/>
                </xsl:call-template>
            </code>
        </li>
    </xsl:template>
    <!-- OLD shape: one assignment line -->
    <xsl:template match="v:assignment">
        <li>
            <code>
                <xsl:choose>
                    <xsl:when test="translate(normalize-space(v:target/@kind),$az,$AZ)='SYSVAR'">
                        <xsl:text>SysVar </xsl:text>
                        <xsl:value-of select="normalize-space(v:target/v:name)"/>
                    </xsl:when>
                    <xsl:when test="translate(normalize-space(v:target/@kind),$az,$AZ)='DBSIGNAL'">
                        <xsl:text>DBSignal </xsl:text>
                        <xsl:choose>
                            <xsl:when test="normalize-space(v:target/v:label)!=''">
                                <xsl:value-of select="normalize-space(v:target/v:label)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="normalize-space(v:target/v:pdu)"/>
                                <xsl:text>.</xsl:text>
                                <xsl:value-of select="normalize-space(v:target/v:signal)"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:call-template name="prettyPath">
                            <xsl:with-param name="raw" select="normalize-space(v:target/v:rawPath)"/>
                        </xsl:call-template>
                    </xsl:otherwise>
                </xsl:choose>
                <xsl:text> = </xsl:text>
                <xsl:value-of select="normalize-space(v:value)"/>
            </code>
        </li>
    </xsl:template>
    <!-- VARIABLES -->
    <xsl:template match="v:variables">
        <li>
            <strong>VARIABLES</strong>
            <ul>
                <xsl:apply-templates select="v:vardef"/>
            </ul>
        </li>
    </xsl:template>
    <xsl:template match="v:vardef">
        <li>
            <code>
                <xsl:value-of select="@name"/>
                <xsl:if test="@type and normalize-space(@type)!=''">:<xsl:value-of select="@type"/>
                </xsl:if>
                <xsl:text> ← </xsl:text>
                <xsl:value-of select="@value"/>
            </code>
        </li>
    </xsl:template>
    <!-- Fallback -->
    <xsl:template match="v:unknown">
        <li class="muted">
            <code>(unhandled: <xsl:value-of select="@tag"/>)</code>
        </li>
    </xsl:template>
</xsl:stylesheet>
