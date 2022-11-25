#Region Private

// The function gets the style color by a style item name.
//
// Parameters:
// StyleColorName - String - Style item name.
//
// Returns:
// Color.
//
Function StyleColor(StyleColorName) Export
	
	Return CommonServerCall.StyleColor(StyleColorName);
	
EndFunction

// The function gets the style font by a style item name.
//
// Parameters:
// StyleFontName - String -  the style font name.
//
// Returns:
// Font.
//
Function StyleFont(StyleFontName) Export
	
	Return CommonServerCall.StyleFont(StyleFontName);
	
EndFunction

// See CommonClientServer.IsMacOSWebClient. 
Function IsMacOSWebClient() Export
	
#If Not WebClient Then
	Return False;  // This script works only in web client mode.
#EndIf
	
	SystemInfo = New SystemInfo;
	If StrFind(SystemInfo.UserAgentInformation, "Macintosh") <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

// See CommonClient.ClientPlatformType. 
Function ClientPlatformType() Export
	SystemInfo = New SystemInfo;
	Return SystemInfo.PlatformType;
EndFunction

#EndRegion
