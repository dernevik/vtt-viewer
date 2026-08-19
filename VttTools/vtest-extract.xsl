<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0" xmlns="urn:vttx:v0.1" exclude-result-prefixes="tt">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- =========================
       Helpers (pure XSLT 1.0)
       ========================= -->
    <!-- last-token: returns substring after the final '|' (or whole string if none) -->
    <xsl:template name="last-token">
        <xsl:param name="s"/>
        <xsl:choose>
            <xsl:when test="contains($s,'|')">
                <xsl:call-template name="last-token">
                    <xsl:with-param name="s" select="substring-after($s,'|')"/>
                </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$s"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- text-between($s,$a,$b): substring between $a and $b (empty if missing) -->
    <xsl:template name="text-between">
        <xsl:param name="s"/>
        <xsl:param name="a"/>
        <xsl:param name="b"/>
        <xsl:choose>
            <xsl:when test="contains($s,$a)">
                <xsl:variable name="t" select="substring-after($s,$a)"/>
                <xsl:choose>
                    <xsl:when test="contains($t,$b)">
                        <xsl:value-of select="substring-before($t,$b)"/>
                    </xsl:when>
                    <xsl:otherwise/>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    <!-- lastAlphaToken: keep recursing until the last '|' token; if it starts with a letter, return it.
       If not, drop back to a safer label (the raw string's last token). -->
    <xsl:template name="lastAlphaToken">
        <xsl:param name="s"/>
        <xsl:variable name="tok">
            <xsl:call-template name="last-token">
                <xsl:with-param name="s" select="$s"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:choose>
            <xsl:when test="translate(substring($tok,1,1),'abcdefghijklmnopqrstuvwxyz','ABCDEFGHIJKLMNOPQRSTUVWXYZ')
                      = substring($tok,1,1)">
                <xsl:value-of select="$tok"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$tok"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- sysvar-label: "SysVar_<path>" -> "<path>" -->
    <xsl:template name="sysvar-label">
        <xsl:param name="raw"/>
        <xsl:choose>
            <xsl:when test="contains($raw,'SysVar_')">
                <xsl:value-of select="substring-after($raw,'SysVar_')"/>
            </xsl:when>
            <xsl:otherwise>
                <xsl:value-of select="$raw"/>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <!-- ================
       Root extraction
       ================ -->
    <xsl:template match="/">
        <vttx>
            <!-- Flat fixtures (as in VTT) with title attribute.
           If you already compute a hierarchical @path elsewhere, you can add it here. -->
            <xsl:for-each select="//tt:tf">
                <fixture title="{normalize-space(tt:title)}">
                    <!-- Test cases -->
                    <xsl:for-each select="tt:tc | tt:tc_definition">
                        <tc title="{normalize-space(tt:title)}" id="{normalize-space(tt:tcid)}">
                            <!-- Preparation -->
                            <prep>
                                <xsl:apply-templates select="tt:preparation/*"/>
                            </prep>
                            <!-- Body: everything except meta blocks -->
                            <body>
                                <xsl:apply-templates select="*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]"/>
                            </body>
                            <!-- Completion -->
                            <comp>
                                <xsl:apply-templates select="tt:completion/*"/>
                            </comp>
                        </tc>
                    </xsl:for-each>
                </fixture>
            </xsl:for-each>
        </vttx>
    </xsl:template>
    <!-- ==========
       WAIT step
       ========== -->
    <xsl:template match="tt:wait">
        <wait>
            <xsl:variable name="const" select="normalize-space(tt:time/tt:value/tt:const)"/>
            <xsl:variable name="unit" select="normalize-space(tt:time/tt:unit)"/>
            <xsl:choose>
                <xsl:when test="$const!=''">
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
    <!-- ================
       VARIABLES block
       ================ -->
    <xsl:template match="tt:variables">
        <variables>
            <xsl:for-each select="tt:variable_definition">
                <var name="{normalize-space(tt:name)}" type="{normalize-space(tt:type)}">
                    <value>
                        <xsl:choose>
                            <xsl:when test="normalize-space(tt:value/tt:valuetable_entry)!=''">
                                <xsl:value-of select="normalize-space(tt:value/tt:valuetable_entry)"/>
                            </xsl:when>
                            <xsl:when test="normalize-space(tt:value/tt:const)!=''">
                                <xsl:value-of select="normalize-space(tt:value/tt:const)"/>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:value-of select="normalize-space(string(tt:value/*[1]))"/>
                            </xsl:otherwise>
                        </xsl:choose>
                    </value>
                </var>
            </xsl:for-each>
        </variables>
    </xsl:template>
    <!-- ======
       SET
       ====== -->
    <xsl:template match="tt:set">
        <set>
            <!-- treat each direct child as a potential assignment row -->
            <xsl:for-each select="*">
                <xsl:variable name="raw" select="normalize-space(string(.))"/>
                <xsl:variable name="isDB" select="contains($raw,'DBSignal_')"/>
                <xsl:variable name="isSV" select="contains($raw,'SysVar_')"/>
                <!-- RHS: prefer valuetable_entry, then const, else text after '=' -->
                <xsl:variable name="rhs">
                    <xsl:choose>
                        <xsl:when test=".//*[local-name()='valuetable_entry' and normalize-space(text())!='']">
                            <xsl:value-of select="normalize-space(.//*[local-name()='valuetable_entry'][1])"/>
                        </xsl:when>
                        <xsl:when test=".//*[local-name()='const' and normalize-space(text())!='']">
                            <xsl:value-of select="normalize-space(.//*[local-name()='const'][1])"/>
                        </xsl:when>
                        <xsl:otherwise>
                            <xsl:value-of select="normalize-space(substring-after($raw,'='))"/>
                        </xsl:otherwise>
                    </xsl:choose>
                </xsl:variable>
                <xsl:if test="$isDB or $isSV">
                    <assignment>
                        <target>
                            <xsl:attribute name="kind">
                                <xsl:choose>
                                    <xsl:when test="$isDB">dbsignal</xsl:when>
                                    <xsl:when test="$isSV">sysvar</xsl:when>
                                    <xsl:otherwise>unknown</xsl:otherwise>
                                </xsl:choose>
                            </xsl:attribute>
                            <rawPath>
                                <xsl:value-of select="$raw"/>
                            </rawPath>
                            <!-- DBSignal: extract pdu + signal -->
                            <xsl:if test="$isDB">
                                <xsl:variable name="fd">
                                    <xsl:call-template name="text-between">
                                        <xsl:with-param name="s" select="$raw"/>
                                        <xsl:with-param name="a" select="'FrameData_BEGIN_OF_OBJECT|'"/>
                                        <xsl:with-param name="b" select="'|END_OF_OBJECT_FrameData|'"/>
                                    </xsl:call-template>
                                </xsl:variable>
                                <xsl:variable name="preTrue" select="substring-before($fd,'|True')"/>
                                <pdu>
                                    <xsl:call-template name="lastAlphaToken">
                                        <xsl:with-param name="s" select="$preTrue"/>
                                    </xsl:call-template>
                                </pdu>
                                <signal>
                                    <xsl:call-template name="lastAlphaToken">
                                        <xsl:with-param name="s" select="$raw"/>
                                    </xsl:call-template>
                                </signal>
                                <label>
                                    <xsl:call-template name="lastAlphaToken">
                                        <xsl:with-param name="s" select="$raw"/>
                                    </xsl:call-template>
                                </label>
                            </xsl:if>
                            <!-- SysVar label -->
                            <xsl:if test="$isSV">
                                <name>
                                    <xsl:value-of select="substring-after($raw,'SysVar_')"/>
                                </name>
                                <label>
                                    <xsl:call-template name="sysvar-label">
                                        <xsl:with-param name="raw" select="$raw"/>
                                    </xsl:call-template>
                                </label>
                            </xsl:if>
                        </target>
                        <value>
                            <xsl:value-of select="$rhs"/>
                        </value>
                    </assignment>
                </xsl:if>
            </xsl:for-each>
        </set>
    </xsl:template>
    <!-- =========
       NETFUNC (minimal)
       ========= -->
    <xsl:template match="tt:netfunction">
        <netfunc name="{normalize-space(tt:name)}" class="{normalize-space(tt:class)}">
            <xsl:for-each select="tt:param">
                <param type="{normalize-space(tt:type)}">
                    <value>
                        <xsl:choose>
                            <xsl:when test="normalize-space(tt:value/tt:valuetable_entry)!=''">
                                <xsl:value-of select="normalize-space(tt:value/tt:valuetable_entry)"/>
                            </xsl:when>
                            <xsl:when test="normalize-space(tt:value/tt:const)!=''">
                                <xsl:value-of select="normalize-space(tt:value/tt:const)"/>
                            </xsl:when>
                            <xsl:when test="normalize-space(tt:value/tt:dbobject)!=''">
                                <xsl:value-of select="normalize-space(tt:value/tt:dbobject)"/>
                            </xsl:when>
                            <xsl:otherwise>?</xsl:otherwise>
                        </xsl:choose>
                    </value>
                </param>
            </xsl:for-each>
        </netfunc>
    </xsl:template>
    <!-- default fallback: mark as unknown so missing handlers are visible -->
    <xsl:template match="*">
        <unknown tag="{local-name()}"/>
    </xsl:template>
</xsl:stylesheet>
