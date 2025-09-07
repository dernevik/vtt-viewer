<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="urn:vttx:v0.1" exclude-result-prefixes="v">
    <xsl:output method="html" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- optional fixture title to render; empty => render all -->
    <xsl:param name="fixture"/>
    <!-- helpers for case-insensitive compare -->
    <xsl:variable name="AZ">ABCDEFGHIJKLMNOPQRSTUVWXYZ</xsl:variable>
    <xsl:variable name="az">abcdefghijklmnopqrstuvwxyz</xsl:variable>
    <!-- ======================== ROOT ======================== -->
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
                    <!-- no filter: render all top-level fixtures -->
                    <xsl:when test="$fx=''">
                        <xsl:apply-templates select="v:vttx/v:fixture"/>
                    </xsl:when>
                    <!-- filter: render any fixtures anywhere whose title matches -->
                    <xsl:otherwise>
                        <xsl:variable name="targets" select="v:vttx//v:fixture[translate(normalize-space(@title),$az,$AZ)=$fxU]"/>
                        <xsl:choose>
                            <xsl:when test="count($targets) &gt; 0">
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
    <!-- ===================== FIXTURE NODE ==================== -->
    <xsl:template match="v:fixture">
        <h2>Fixture: <xsl:value-of select="@title"/>
        </h2>
        <!-- Show test cases if present -->
        <xsl:if test="v:tc">
            <ul>
                <xsl:apply-templates select="v:tc"/>
            </ul>
        </xsl:if>
        <!-- Recurse into child fixtures -->
        <xsl:apply-templates select="v:fixture"/>
        <!-- If truly empty (no tcs and no child fixtures), say so -->
        <xsl:if test="not(v:tc) and not(v:fixture)">
            <p class="muted">(no test cases)</p>
        </xsl:if>
    </xsl:template>
    <!-- ===================== TEST CASE ======================= -->
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
    <!-- ====================== STEPS ========================== -->
    <!-- WAIT -->
    <xsl:template match="v:wait">
        <li>
            <code>WAIT
        <xsl:text> </xsl:text>
                <xsl:choose>
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
            <code>NETFUNC <xsl:value-of select="@name"/>(
        <xsl:for-each select="v:param">
                    <xsl:if test="position()&gt;1">, </xsl:if>
                    <xsl:choose>
                        <xsl:when test="@type='String'">"<xsl:value-of select="v:value"/>"</xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="v:value"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:for-each>
      ) — class=<xsl:value-of select="@class"/>
            </code>
        </li>
    </xsl:template>
    <!-- unknown tags: keep visible so we know what to add next -->
    <xsl:template match="v:unknown">
        <li class="muted">
            <code>(unhandled: <xsl:value-of select="@tag"/>)</code>
        </li>
    </xsl:template>
</xsl:stylesheet>
