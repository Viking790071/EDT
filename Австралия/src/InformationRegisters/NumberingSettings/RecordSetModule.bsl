#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	For Each Record In ThisObject Do
		Record.Presentation = Numbering.GeneratePresentationField(Record.Numerator);
	EndDo;
	
EndProcedure

Procedure OnWrite(Cancel, Replacing)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	SetPrivilegedMode(True);
	
	Dimensions = Metadata.InformationRegisters.NumberingSettings.Dimensions;
	
	For Each Record In ThisObject Do
		
		FilledDimensions = New Array;
		BlankDimensions = New Array;
		
		For Each Dimension In Dimensions Do
			
			DimensionName = Dimension.Name;
			
			If ValueIsFilled(Record[DimensionName]) Then 
				FilledDimensions.Add(DimensionName);
			Else
				BlankDimensions.Add(DimensionName);
			EndIf;
			
		EndDo;
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	NumberingSettings.DocumentType,
		|	NumberingSettings.OperationType,
		|	NumberingSettings.Company,
		|	NumberingSettings.BusinessUnit,
		|	NumberingSettings.Counterparty,
		|	NumberingSettings.Numerator
		|FROM
		|	InformationRegister.NumberingSettings AS NumberingSettings";
		
		FoundRows = New Array;
		
		Result = Query.Execute().Unload();
		For Each Row In Result Do
			
			HasDifferences = False;
			For Each FilledDimension In FilledDimensions Do
				If ValueIsFilled(Row[FilledDimension])
					And Row[FilledDimension] <> Record[FilledDimension] Then 
					HasDifferences = True;
					Break;
				EndIf;
			EndDo;
			
			If HasDifferences Then 
				Continue;
			EndIf;
			
			For Each FilledDimension In FilledDimensions Do
				If Not ValueIsFilled(Row[FilledDimension]) Then 
					FoundRows.Add(Row);
					Break;
				EndIf;
			EndDo;
			
		EndDo;
		
		For Each BlankDimension In BlankDimensions Do
			For Each Row In FoundRows Do
				If ValueIsFilled(Row[BlankDimension]) Then 
					MessageText = StringFunctionsClientServer.SubstituteParametersToString(
						NStr("en = 'The ""%1"" setting leads to a possible ambiguous determination of numbering parameters with the ""%2"" setting.'; ru = 'Настройка ""%1"" может к привести к неоднозначному определению параметров нумерации при использовании параметра ""%2"".';pl = 'Ustawienie ""%1"" prowadzi do możliwego dwuznacznego określenia parametrów numeracji z ustawieniem ""%2"".';es_ES = 'La ""%1"" configuración conduce a una posible determinación ambigua de los parámetros de numeración con la ""%2"" configuración.';es_CO = 'La ""%1"" configuración conduce a una posible determinación ambigua de los parámetros de numeración con la ""%2"" configuración.';tr = '""%1"" ayarı, ""%2"" ayarıyla numaralandırma parametrelerinin olası belirsiz bir şekilde belirlenmesine yol açar.';it = 'L''impostazione ""%1"" porta ad una possibile determinazione ambigua dei parametri numerici con l''impostazione ""%2"".';de = 'Die Einstellung ""%1"" führt zu einer möglichen mehrdeutigen Bestimmung der Nummerierungsparameter mit der Einstellung ""%2"".'"),
						RecordPresentation(Record),
						RecordPresentation(Row));
						Raise MessageText;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function RecordPresentation(Record)
	
	FilledDimensions = New Array;
	
	Dimensions = Metadata.InformationRegisters.NumberingSettings.Dimensions;
	For Each Dimension In Dimensions Do
		
		DimensionName = Dimension.Name;
		
		If ValueIsFilled(Record[DimensionName]) Then 
			FilledDimensions.Add(DimensionName);
		EndIf;
		
	EndDo;
	
	Presentation = "";
	For Each FilledDimension In FilledDimensions Do
		Presentation = Presentation + Record[FilledDimension] + ", ";
	EndDo;
	If Presentation <> "" Then 
		Presentation = Left(Presentation, StrLen(Presentation) - 2);
	EndIf;
	
	Return Presentation;
	
EndFunction

#EndRegion

#EndIf