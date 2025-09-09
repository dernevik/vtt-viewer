<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:tt="http://www.vector-informatik.de/ITE/TestTable/1.0" xmlns="urn:vttx:v0.1" exclude-result-prefixes="tt">
    <xsl:output method="xml" indent="yes"/>
    <xsl:strip-space elements="*"/>
    <!-- ========== Token helpers (single, canonical versions) ========== -->
    <!-- substring after last occurrence of $delim (default '|') -->
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
    <!-- substring before last occurrence of $delim -->
    <xsl:template name="before-last">
        <xsl:param name="s"/>
        <xsl:param name="delim" select="'|'"/>
        <xsl:variable name="last">
            <xsl:call-template name="after-last">
                <xsl:with-param name="s" select="$s"/>
                <xsl:with-param name="delim" select="$delim"/>
            </xsl:call-template>
        </xsl:variable>
        <xsl:value-of select="substring-before($s, concat($delim,$last))"/>
    </xsl:template>
    <!-- join everything except the last token with '::' (for SysVar namespaces) -->
    <xsl:template name="join-namespace">
        <xsl:param name="s"/>
        <xsl:choose>
            <xsl:when test="contains($s,'|')">
                <xsl:variable name="head" select="substring-before($s,'|')"/>
                <xsl:variable name="tail" select="substring-after($s,'|')"/>
                <xsl:choose>
                    <xsl:when test="contains($tail,'|')">
                        <xsl:value-of select="$head"/>
                        <xsl:text>::</xsl:text>
                        <xsl:call-template name="join-namespace">
                            <xsl:with-param name="s" select="$tail"/>
                        </xsl:call-template>
                    </xsl:when>
                    <xsl:otherwise>
                        <xsl:value-of select="$head"/>
                    </xsl:otherwise>
                </xsl:choose>
            </xsl:when>
            <xsl:otherwise/>
        </xsl:choose>
    </xsl:template>
    <!-- Return PDU name from a DBSignal dbobject path -->
    <xsl:template name="pduFromDbobj">
        <xsl:param name="path"/>
        <!-- Slice the FrameData segment -->
        <xsl:variable name="frame" select="substring-before(substring-after($path,'FrameData_BEGIN_OF_OBJECT|'),
                             '|END_OF_OBJECT_FrameData|')"/>
        <!-- Your data always looks like: 1|255|255|0|0|PDU|0|True -->
        <xsl:variable name="afterHdr" select="substring-after($frame,'|0|0|')"/>
        <xsl:value-of select="substring-before($afterHdr,'|')"/>
    </xsl:template>
    <!-- Return signal name from a DBSignal dbobject path -->
    <xsl:template name="signalFromDbobj">
        <xsl:param name="path"/>
        <!-- After the FrameData block comes: SIGNAL|3|END_OF_OBJECT_| -->
        <xsl:variable name="afterFrame" select="substring-after($path,'|END_OF_OBJECT_FrameData|')"/>
        <xsl:value-of select="substring-before($afterFrame,'|')"/>
    </xsl:template>
    <!-- Pretty sysvar label: DOMAIN::Path::To::Var
     Paths look like: SysVar_BEGIN_OF_OBJECT|1|DOMAIN|Path::To::Var|-1|0|END_OF_OBJECT_SysVar| -->
    <xsl:template name="sysvarLabel">
        <xsl:param name="path"/>
        <xsl:variable name="core" select="substring-before(substring-after($path,'SysVar_BEGIN_OF_OBJECT|'),
                             '|END_OF_OBJECT_SysVar|')"/>
        <!-- drop the leading '1' token -->
        <xsl:variable name="afterOne" select="substring-after($core,'|')"/>
        <xsl:variable name="domain" select="substring-before($afterOne,'|')"/>
        <xsl:variable name="rest" select="substring-after($afterOne,'|')"/>
        <!-- up to the |-1| marker -->
        <xsl:variable name="varpath" select="substring-before($rest,'|-1|')"/>
        <xsl:value-of select="concat($domain,'::',$varpath)"/>
    </xsl:template>
    <!-- ========== ROOT: keep hierarchical fixtures ========== -->
    <xsl:template match="/">
        <vttx>
            <xsl:apply-templates select="//tt:tf[not(ancestor::tt:tf)]" mode="fixture"/>
        </vttx>
    </xsl:template>
    <!-- Recursive fixture -->
    <xsl:template match="tt:tf" mode="fixture">
        <fixture title="{normalize-space(tt:title)}">
            <!-- test cases in this fixture -->
            <xsl:apply-templates select="tt:tc | tt:tc_definition" mode="tc"/>
            <!-- child fixtures -->
            <xsl:apply-templates select="tt:tf" mode="fixture"/>
        </fixture>
    </xsl:template>
    <!-- Test case -->
    <xsl:template match="tt:tc | tt:tc_definition" mode="tc">
        <tc title="{normalize-space(tt:title)}" id="{normalize-space(tt:tcid)}">
            <prep>
                <xsl:apply-templates select="tt:preparation/*"/>
            </prep>
            <body>
                <xsl:apply-templates select="*[not(self::tt:title or self::tt:tcid or self::tt:attributes or self::tt:traceitems or self::tt:preparation or self::tt:completion or self::tt:active or self::tt:breakonfail)]"/>
            </body>
            <comp>
                <xsl:apply-templates select="tt:completion/*"/>
            </comp>
        </tc>
    </xsl:template>
    <!-- ========== STEPS ========== -->
    <!-- WAIT -->
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
    <!-- NETFUNC -->
    <xsl:template match="tt:netfunction">
        <netfunc name="{normalize-space(tt:name)}" class="{normalize-space(tt:class)}">
            <xsl:for-each select="tt:param">
                <param type="{normalize-space(tt:type)}">
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
    <!-- ===== SET: extract assignments with structured targets ===== -->
    <xsl:template match="tt:set">
        <set>
            <xsl:for-each select="tt:in/tt:assignment">
                <assignment>
                    <xsl:variable name="dbo" select="normalize-space(tt:sink/tt:dbobject)"/>
                    <target>
                        <xsl:attribute name="kind">
                            <xsl:choose>
                                <xsl:when test="starts-with($dbo,'SysVar')">sysvar</xsl:when>
                                <xsl:when test="starts-with($dbo,'DBSignal')">dbsignal</xsl:when>
                                <xsl:otherwise>raw</xsl:otherwise>
                            </xsl:choose>
                        </xsl:attribute>
                        <rawPath>
                            <xsl:value-of select="$dbo"/>
                        </rawPath>
                        <!-- sysvar label -->
                        <xsl:if test="starts-with($dbo,'SysVar')">
                            <name>
                                <xsl:call-template name="sysvarLabel">
                                    <xsl:with-param name="path" select="$dbo"/>
                                </xsl:call-template>
                            </name>
                        </xsl:if>
                        <!-- dbsignal: pdu + signal + friendly label -->
                        <xsl:if test="starts-with($dbo,'DBSignal')">
                            <pdu>
                                <xsl:call-template name="pduFromDbobj">
                                    <xsl:with-param name="path" select="$dbo"/>
                                </xsl:call-template>
                            </pdu>
                            <signal>
                                <xsl:call-template name="signalFromDbobj">
                                    <xsl:with-param name="path" select="$dbo"/>
                                </xsl:call-template>
                            </signal>
                            <label>
                                <xsl:variable name="p">
                                    <xsl:call-template name="pduFromDbobj">
                                        <xsl:with-param name="path" select="$dbo"/>
                                    </xsl:call-template>
                                </xsl:variable>
                                <xsl:variable name="s">
                                    <xsl:call-template name="signalFromDbobj">
                                        <xsl:with-param name="path" select="$dbo"/>
                                    </xsl:call-template>
                                </xsl:variable>
                                <xsl:value-of select="concat($p,'.',$s)"/>
                            </label>
                        </xsl:if>
                    </target>
                    <!-- right-hand side value -->
                    <value>
                        <xsl:value-of select="normalize-space(tt:value/*[1])"/>
                    </value>
                </assignment>
            </xsl:for-each>
        </set>
    </xsl:template>
    <!-- VARIABLES -->
    <xsl:template match="tt:variables">
        <variables>
            <xsl:apply-templates select="tt:variable_definition"/>
        </variables>
    </xsl:template>
    <xsl:template match="tt:variable_definition">
        <vardef name="{normalize-space(tt:name)}">
            <xsl:if test="normalize-space(tt:type)!=''">
                <xsl:attribute name="type">
                    <xsl:value-of select="normalize-space(tt:type)"/>
                </xsl:attribute>
            </xsl:if>
            <xsl:choose>
                <xsl:when test="normalize-space(tt:source/tt:value/tt:const)!=''">
                    <xsl:attribute name="kind">const</xsl:attribute>
                    <xsl:attribute name="value">
                        <xsl:value-of select="normalize-space(tt:source/tt:value/tt:const)"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:when test="normalize-space(tt:source/tt:valuetable_entry)!=''">
                    <xsl:attribute name="kind">valuetable</xsl:attribute>
                    <xsl:attribute name="value">
                        <xsl:value-of select="normalize-space(tt:source/tt:valuetable_entry)"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:when test="normalize-space(tt:source/tt:variable)!=''">
                    <xsl:attribute name="kind">variable</xsl:attribute>
                    <xsl:attribute name="value">
                        <xsl:value-of select="normalize-space(tt:source/tt:variable)"/>
                    </xsl:attribute>
                </xsl:when>
                <xsl:otherwise>
                    <xsl:attribute name="kind">text</xsl:attribute>
                    <xsl:attribute name="value">
                        <xsl:value-of select="normalize-space(tt:source)"/>
                    </xsl:attribute>
                </xsl:otherwise>
            </xsl:choose>
        </vardef>
    </xsl:template>
    <!-- Fallback so we see what's left to handle -->
    <xsl:template match="*">
        <unknown tag="{local-name()}"/>
    </xsl:template>
</xsl:stylesheet>
