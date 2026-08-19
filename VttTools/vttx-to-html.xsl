<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:v="urn:vttx:v0.1" exclude-result-prefixes="v">
    <xsl:output method="html" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- Optional filter: exact fixture title. Empty => render all. -->
    <xsl:param name="fixture"/>
    <xsl:template match="/">
        <html>
            <head>
                <meta charset="utf-8"/>
                <title>VTT Render</title>
                <style>
          body{font-family:Segoe UI,Arial,sans-serif;line-height:1.35;padding:1rem;}
          h2{margin:.8rem 0 .2rem}
          code{background:#f6f8fa;padding:0 .25rem;border-radius:.25rem}
          ul{margin:.25rem 0 .75rem 1.25rem}
          .muted{color:#666}
        </style>
            </head>
            <body>
                <xsl:apply-templates select="v:vttx/v:fixture[not($fixture) or @title=$fixture]"/>
            </body>
        </html>
    </xsl:template>
    <xsl:template match="v:fixture">
        <h2>Fixture: <xsl:value-of select="@title"/>
        </h2>
        <xsl:apply-templates select="v:tc"/>
    </xsl:template>
    <xsl:template match="v:tc">
        <h2>TestCase: <xsl:value-of select="@title"/>
        </h2>
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
    <!-- WAIT -->
    <xsl:template match="v:wait">
        <li>
            <code>WAIT
      <xsl:choose>
                    <xsl:when test="normalize-space(v:ms)!=''">
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="v:ms"/>
                        <xsl:text> ms</xsl:text>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:text> </xsl:text>
                        <xsl:value-of select="v:label"/>
                        <xsl:if test="normalize-space(v:unit)!=''">
                            <xsl:text> </xsl:text>
                            <xsl:value-of select="v:unit"/>
                        </xsl:if>
                    </xsl:otherwise>
                </xsl:choose>
            </code>
        </li>
    </xsl:template>
    <!-- VARIABLES -->
    <xsl:template match="v:variables">
        <li>
            <strong>VARIABLES</strong>
            <ul>
                <xsl:for-each select="v:var">
                    <li>
                        <code>
                            <xsl:value-of select="@name"/>
                            <xsl:text>:</xsl:text>
                            <xsl:value-of select="@type"/>
                            <xsl:text> ← </xsl:text>
                            <xsl:value-of select="v:value"/>
                        </code>
                    </li>
                </xsl:for-each>
            </ul>
        </li>
    </xsl:template>
    <!-- SET (normalized shape only) -->
    <xsl:template match="v:set">
        <li>
            <strong>SET</strong>
            <ul>
                <xsl:for-each select="v:assignment">
                    <li>
                        <code>
                            <xsl:choose>
                                <xsl:when test="v:target/@kind='dbsignal'">
                                    <xsl:text>DBSignal </xsl:text>
                                    <xsl:value-of select="v:target/v:pdu"/>
                                    <xsl:text>.</xsl:text>
                                    <xsl:value-of select="v:target/v:signal"/>
                                </xsl:when>
                                <xsl:when test="v:target/@kind='sysvar'">
                                    <xsl:text>SysVar </xsl:text>
                                    <xsl:value-of select="v:target/v:name"/>
                                </xsl:when>
                                <xsl:otherwise>
                                    <xsl:value-of select="v:target/v:label"/>
                                </xsl:otherwise>
                            </xsl:choose>
                            <xsl:text> = </xsl:text>
                            <xsl:value-of select="v:value"/>
                        </code>
                    </li>
                </xsl:for-each>
            </ul>
        </li>
    </xsl:template>
    <!-- NETFUNC (minimal) -->
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
    <!-- Fallback: show what's left, clearly marked -->
    <xsl:template match="*">
        <li class="muted">
            <code>(unhandled: <xsl:value-of select="concat(namespace-uri(),':',local-name())"/>)</code>
        </li>
    </xsl:template>
</xsl:stylesheet>
