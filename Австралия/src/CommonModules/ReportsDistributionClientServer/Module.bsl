///////////////////////////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2019, 1C-Soft LLC
// All Rights reserved. This application and supporting materials are provided under the terms of 
// Attribution 4.0 International license (CC BY 4.0)
// The license text is available at:
// https://creativecommons.org/licenses/by/4.0/legalcode
///////////////////////////////////////////////////////////////////////////////////////////////////////

#Region Private

// Fills a template from the parameters structure, supports formatting, can leave templates borders.
//   Restriction: the left and right items of borders are to be.
//
// Parameters:
//   Template - String - an initial template. For instance "Welcome, [ФИО]".
//   Parameters - Structure - a set of parameters that you need to substitute into the template.
//      * Key - a parameter name. For instance Full name.
//      * Value - a substitution string. For instance John Smith.
//
// Returns:
//   String - a template with filled parameters.
//
Function FillTemplate(Template, Parameters) Export
	Left = "["; // Parameter borders start.
	Right = "]"; // Parameter borders end.
	LeftFormat = "("; // Format borders start.
	RightFormat = ")"; // Format borders end.
	CutBorders = True; // True means that the parameter borders will be removed from the result.
	
	Result = Template;
	For Each KeyAndValue In Parameters Do
		// Replace a "[ключ]" with a "value".
		Result = StrReplace(
			Result,
			Left + KeyAndValue.Key + Right, 
			?(CutBorders, "", Left) + KeyAndValue.Value + ?(CutBorders, "", Right));
		LengthLeftFormat = StrLen(Left + KeyAndValue.Key + LeftFormat);
		// Replace [key(format)] to value in the format.
		Pos1 = StrFind(Result, Left + KeyAndValue.Key + LeftFormat);
		While Pos1 > 0 Do
			Pos2 = StrFind(Result, RightFormat + Right);
			If Pos2 = 0 Then
				Break;
			EndIf;
			FormatString = Mid(Result, Pos1 + LengthLeftFormat, Pos2 - Pos1 - LengthLeftFormat);
			Try
				WhatToReplace = ?(CutBorders, "", Left) + Format(KeyAndValue.Value, FormatString) + ?(CutBorders, "", Right);
			Except
				WhatToReplace = ?(CutBorders, "", Left) + KeyAndValue.Value + ?(CutBorders, "", Right);
			EndTry;
			Result = StrReplace(
				Result,
				Left + KeyAndValue.Key + LeftFormat + FormatString + RightFormat + Right, 
				WhatToReplace);
			Pos1 = StrFind(Result, Left + KeyAndValue.Key + LeftFormat);
		EndDo;
	EndDo;
	Return Result;
EndFunction

// Generates the delivery methods presentation according to delivery parameters.
//
// Parameters:
//   DeliveryParameters - Structure - see ExecuteMailing(), the DeliveryParameters parameter. 
//
// Returns:
//   String - a delivery methods presentation.
//
Function DeliveryMethodsPresentation(DeliveryParameters) Export
	Prefix = NStr("ru = 'Результат'; en = 'Result'; pl = 'Wynik';es_ES = 'Resultado';es_CO = 'Resultado';tr = 'Sonuç';it = 'Risultato';de = 'Ergebnis'");
	PresentationText = "";
	Suffix = "";
	
	If Not DeliveryParameters.NotifyOnly Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("ru = 'и'; en = 'and'; pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'")) 
		+ " "
		+ NStr("ru = 'отправлен по почте (см. вложения)'; en = 'sent by email (see attachments)'; pl = 'wysłane e-mailem (patrz załączniki)';es_ES = 'enviado por correo electrónico (véase los archivos adjuntos)';es_CO = 'enviado por correo electrónico (véase los archivos adjuntos)';tr = 'e-posta ile gönderildi (eklere bakınız)';it = 'inviato per posta (vedi allegati)';de = 'per E-Mail gesendet (siehe Anlagen)'");
		
	EndIf;
	
	If DeliveryParameters.ExecutedToFolder Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("ru = 'и'; en = 'and'; pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'")) 
		+ " "
		+ NStr("ru = 'доставлен в папку'; en = 'delivered to folder'; pl = 'dostarczone do foldera';es_ES = 'entregado a la carpeta';es_CO = 'entregado a la carpeta';tr = 'klasöre teslim edildi';it = 'consegnato nella cartella';de = 'zugestellt in Ordner'")
		+ " ";
		
		Ref = GetInfoBaseURL() +"#"+ GetURL(DeliveryParameters.Folder);
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ Ref
			+ "'>" 
			+ String(DeliveryParameters.Folder)
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ """"
			+ String(DeliveryParameters.Folder)
			+ """";
			Suffix = Suffix + ":" + Chars.LF + "<" + Ref + ">";
		EndIf;
		
	EndIf;
	
	If DeliveryParameters.ExecutedToNetworkDirectory Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("ru = 'и'; en = 'and'; pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'")) 
		+ " "
		+ NStr("ru = 'доставлен в сетевой каталог'; en = 'delivered to network directory'; pl = 'dostarczone do katalogu sieci';es_ES = 'entregado al catálogo de la red';es_CO = 'entregado al catálogo de la red';tr = 'ağ dizinine teslim edildi';it = 'consegnato nella directory di rete';de = 'zugestellt in Netzwerkverzeichnis'")
		+ " ";
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ DeliveryParameters.NetworkDirectoryWindows
			+ "'>" 
			+ DeliveryParameters.NetworkDirectoryWindows
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ "<"
			+ DeliveryParameters.NetworkDirectoryWindows
			+ ">";
		EndIf;
		
	EndIf;
	
	If DeliveryParameters.ExecutedAtFTP Then
		
		PresentationText = PresentationText 
		+ ?(PresentationText = "", Prefix, " " + NStr("ru = 'и'; en = 'and'; pl = 'oraz';es_ES = 'y';es_CO = 'y';tr = 've';it = 'e';de = 'und'")) 
		+ " "
		+ NStr("ru = 'доставлен на FTP-ресурс'; en = 'delivered to FTP resource'; pl = 'dostarczone na serwer FTP';es_ES = 'entregado al recurso FTP';es_CO = 'entregado al recurso FTP';tr = 'FTP kaynağına teslim edildi';it = 'consegnato nella risorsa FTP';de = 'zugestellt zu FTP-Ressource'")
		+ " ";
		
		Ref = "ftp://"
		+ DeliveryParameters.Server 
		+ ":"
		+ Format(DeliveryParameters.Port, "NZ=0; NG=0") 
		+ DeliveryParameters.Directory;
		
		If DeliveryParameters.HTMLFormatEmail Then
			PresentationText = PresentationText 
			+ "<a href = '"
			+ Ref
			+ "'>" 
			+ Ref
			+ "</a>";
		Else
			PresentationText = PresentationText 
			+ "<"
			+ Ref
			+ ">";
		EndIf;
		
	EndIf;
	
	PresentationText = PresentationText + ?(Suffix = "", ".", Suffix);
	
	Return PresentationText;
EndFunction

Function ListPresentation(Collection, ColumnName = "", MaxChars = 60) Export
	Result = New Structure;
	Result.Insert("Total", 0);
	Result.Insert("LengthOfFull", 0);
	Result.Insert("LengthOfShort", 0);
	Result.Insert("Short", "");
	Result.Insert("Full", "");
	Result.Insert("MaximumExceeded", False);
	For Each Object In Collection Do
		ValuePresentation = String(?(ColumnName = "", Object, Object[ColumnName]));
		If IsBlankString(ValuePresentation) Then
			Continue;
		EndIf;
		If Result.Total = 0 Then
			Result.Total        = 1;
			Result.Full       = ValuePresentation;
			Result.LengthOfFull = StrLen(ValuePresentation);
		Else
			Full       = Result.Full + ", " + ValuePresentation;
			LengthOfFull = Result.LengthOfFull + 2 + StrLen(ValuePresentation);
			If Not Result.MaximumExceeded AND LengthOfFull > MaxChars Then
				Result.Short          = Result.Full;
				Result.LengthOfShort    = Result.LengthOfFull;
				Result.MaximumExceeded = True;
			EndIf;
			Result.Total        = Result.Total + 1;
			Result.Full       = Full;
			Result.LengthOfFull = LengthOfFull;
		EndIf;
	EndDo;
	If Result.Total > 0 AND Not Result.MaximumExceeded Then
		Result.Short       = Result.Full;
		Result.LengthOfShort = Result.LengthOfFull;
		Result.MaximumExceeded = Result.LengthOfFull > MaxChars;
	EndIf;
	Return Result;
EndFunction

#EndRegion
