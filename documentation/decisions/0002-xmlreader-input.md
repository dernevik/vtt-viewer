\# 0002 – Use XmlReader to feed XSLT

Status: Accepted

Date: 

Supersedes: 0001 (XmlDocument input)



Context: We previously loaded VTT with XmlDocument/XPathDocument; `xsl:strip-space`

no longer removed insignificant whitespace, causing glued tokens in output.



Decision: Feed XSLT with XmlReader (PowerShell: XmlReaderSettings + XslCompiledTransform).



Consequences: Predictable whitespace handling; lower memory; consistent behavior across phases. Much manual rendering of correct formatting.

