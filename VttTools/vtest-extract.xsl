<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0" xmlns="urn:vttx:v0.1" exclude-result-prefixes="tt">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- ===================== ROOT ===================== -->
    <!-- Start at top-level fixtures (those not inside another fixture) -->
    <xsl:template match="/">
        <vttx>
            <xsl:apply-templates select="//tt:tf[not(ancestor::tt:tf)]" mode="fixture"/>
        </vttx>
    </xsl:template>
    <!-- ===================== FIXTURE (recursive) ===================== -->
    <!-- Render a fixture and then recurse into child fixtures -->
    <xsl:template match="tt:tf" mode="fixture">
        <fixture>
            <xsl:attribute name="title">
                <xsl:value-of select="normalize-space(tt:title)"/>
            </xsl:attribute>
            <!-- Test cases in this fixture -->
            <xsl:apply-templates select="tt:tc | tt:tc_definition" mode="tc"/>
            <!-- Child fixtures (keep structure) -->
            <xsl:apply-templates select="tt:tf" mode="fixture"/>
        </fixture>
    </xsl:template>
    <!-- ===================== TEST CASE ===================== -->
    <xsl:template match="tt:tc | tt:tc_definition" mode="tc">
        <tc>
            <xsl:attribute name="title">
                <xsl:value-of select="normalize-space(tt:title)"/>
            </xsl:attribute>
            <xsl:attribute name="id">
                <xsl:value-of select="normalize-space(tt:tcid)"/>
            </xsl:attribute>
            <!-- Preparation -->
            <prep>
                <xsl:apply-templates select="tt:preparation/*"/>
            </prep>
            <!-- Body steps (skip meta) -->
            <body>
                <xsl:apply-templates select="*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems
                        or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]"/>
            </body>
            <!-- Completion -->
            <comp>
                <xsl:apply-templates select="tt:completion/*"/>
            </comp>
        </tc>
    </xsl:template>
    <!-- ===================== STEPS (unchanged logic) ===================== -->
    <!-- WAIT -->
    <xsl:template match="tt:wait">
        <wait>
            <!-- Prefer const; else try best-effort variable display -->
            <xsl:variable name="const" select="normalize-space(tt:time/tt:value/tt:const)"/>
            <xsl:variable name="unit" select="normalize-space(tt:time/tt:unit)"/>
            <xsl:choose>
                <xsl:when test="$const!=''">
                    <!-- normalize to ms if unit is 's' -->
                    <xsl:variable name="ms">
                        <xsl:choose>
                            <xsl:when test="translate($unit,'S','s')='s'">
                                <xsl:value-of select="format-number(number($const) * 1000,'0')"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="$const"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:variable>
                    <ms>
                        <xsl:value-of select="$ms"/>
                    </ms>
                </xsl:when>
                <xsl:otherwise>
                    <label>
                        <xsl:value-of select="normalize-space(string(tt:time/tt:value/*[1]))"/>
                    </label>
                    <unit>
                        <xsl:value-of select="$unit"/>
                    </unit>
                </xsl:otherwise>
            </xsl:choose>
        </wait>
    </xsl:template>
    <!-- NETFUNC -->
    <xsl:template match="tt:netfunction">
        <netfunc>
            <xsl:attribute name="name">
                <xsl:value-of select="normalize-space(tt:name)"/>
            </xsl:attribute>
            <xsl:attribute name="class">
                <xsl:value-of select="normalize-space(tt:class)"/>
            </xsl:attribute>
            <xsl:for-each select="tt:param">
                <param>
                    <xsl:attribute name="type">
                        <xsl:value-of select="normalize-space(tt:type)"/>
                    </xsl:attribute>
                    <xsl:choose>
                        <xsl:when test="normalize-space(tt:value/tt:valuetable_entry)!=''">
                            <value>
                                <xsl:value-of select="normalize-space(tt:value/tt:valuetable_entry)"/>
                            </value>
                        </xsl:when>
                        <xsl:when test="normalize-space(tt:value/tt:const)!=''">
                            <value>
                                <xsl:value-of select="normalize-space(tt:value/tt:const)"/>
                            </value>
                        </xsl:when>
                        <xsl:when test="normalize-space(tt:value/tt:dbobject)!=''">
                            <value>
                                <xsl:value-of select="normalize-space(tt:value/tt:dbobject)"/>
                            </value>
                        </xsl:when>
                        <xsl:otherwise>
                            <value>?</value>
                        </xsl:otherwise>
                    </xsl:choose>
                </param>
            </xsl:for-each>
        </netfunc>
    </xsl:template>
    <!-- Fallback: mark unhandled nodes so we can see what's left -->
    <xsl:template match="*">
        <unknown tag="{local-name()}"/>
    </xsl:template>
</xsl:stylesheet>
