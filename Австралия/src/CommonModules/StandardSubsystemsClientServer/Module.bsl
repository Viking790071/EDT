#Region Internal

// Calculates the numeric cell indicators in the spreadsheet document.
// See also ReportsClient.SelectedAreas
//
// Parameters:
//   SpreadsheetDocument - SpreadsheetDocument - a table for which calculation is required.
//   SelectedAreas
//       - Undefined - when calling from a client, this parameter is determined automatically.
//       - When calling from a server, pass here areas, precalculated on the client using 
//           ReportsClient.SelectedAreas(SpreadsheetDocument).
//           
//
// Returns:
//   Structure - results of selected cell calculation.
//       * Count - Number - selected cells count.
//       * NumericCellsCount - Number - numeric cells count.
//       * Sum - Number - a sum of the selected cells with numbers.
//       * Average - Number - a sum of the selected cells with numbers.
//       * Minimum - Number - a sum of the selected cells with numbers.
//       * Maximum - Number - a sum of the selected cells with numbers.
//       * ServerCalledNeeded - Boolean - True when calculation on the client is inappropriate and server call is required.
//
Function CalculateCells(SpreadsheetDocument, SelectedAreas) Export
	Result = New Structure;
	Result.Insert("Count", 0);
	Result.Insert("FilledCellsCount", 0);
	Result.Insert("NumericCellsCount", 0);
	Result.Insert("Amount", 0);
	Result.Insert("Mean", 0);
	Result.Insert("Minimum", Undefined);
	Result.Insert("Maximum", Undefined);
	Result.Insert("ServerCalledNeeded", False);
	
	If SelectedAreas = Undefined Then
		#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
			Raise NStr("ru = 'Не указано значение параметра ""SelectedAreas"".'; en = 'The SelectedAreas parameter is not specified.'; pl = 'Nie określono wartości parametru SelectedAreas';es_ES = 'Valor del parámetro SelectedAreas no está especificado.';es_CO = 'Valor del parámetro SelectedAreas no está especificado.';tr = 'SelectedAreas parametresinin değeri belirlenmedi.';it = 'Il parametro SelectedAreas non è specificato.';de = 'Der Wert des Parameters AusgewählteBereiche wird nicht angegeben.'");
		#Else
			SelectedAreas = SpreadsheetDocument.SelectedAreas;
		#EndIf
	EndIf;
	
	CheckedCells = New Map;
	
	For Each SelectedArea In SelectedAreas Do
		If TypeOf(SelectedArea) <> Type("SpreadsheetDocumentRange")
			AND TypeOf(SelectedArea) <> Type("Structure") Then
			Continue;
		EndIf;
		
		SelectedAreaTop  = SelectedArea.Top;
		SelectedAreaBottom   = SelectedArea.Bottom;
		SelectedAreaLeft  = SelectedArea.Left;
		SelectedAreaRight = SelectedArea.Right;
		
		If SelectedAreaTop = 0 Then
			SelectedAreaTop = 1;
		EndIf;
		
		If SelectedAreaBottom = 0 Then
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		If SelectedAreaLeft = 0 Then
			SelectedAreaLeft = 1;
		EndIf;
		
		If SelectedAreaRight = 0 Then
			SelectedAreaRight = SpreadsheetDocument.TableWidth;
		EndIf;
		
		If SelectedArea.AreaType = SpreadsheetDocumentCellAreaType.Columns Then
			SelectedAreaTop = SelectedArea.Bottom;
			SelectedAreaBottom = SpreadsheetDocument.TableHeight;
		EndIf;
		
		SelectedAreaHeight = SelectedAreaBottom   - SelectedAreaTop + 1;
		SelectedAreaWidth = SelectedAreaRight - SelectedAreaLeft + 1;
		
		Result.Count = Result.Count + SelectedAreaWidth * SelectedAreaHeight;
		#If Not Server AND Not ThickClientOrdinaryApplication AND Not ExternalConnection Then
			If Result.Count >= 1000 Then
				Result.ServerCalledNeeded = True;
				Return Result;
			EndIf;
		#EndIf
		
		For ColumnNumber = SelectedAreaLeft To SelectedAreaRight Do
			For RowNumber = SelectedAreaTop To SelectedAreaBottom Do
				Cell = SpreadsheetDocument.Area(RowNumber, ColumnNumber, RowNumber, ColumnNumber);
				If CheckedCells.Get(Cell.Name) = Undefined Then
					CheckedCells.Insert(Cell.Name, True);
				Else
					Continue;
				EndIf;
				
				If Cell.Visible = True Then
					If Cell.AreaType <> SpreadsheetDocumentCellAreaType.Columns
						AND Cell.ContainsValue AND TypeOf(Cell.Value) = Type("Number") Then
						Number = Cell.Value;
					ElsIf ValueIsFilled(Cell.Text) Then
						TypeDescriptionNumber = New TypeDescription("Number");
						
						CellText = Cell.Text;
						If StrStartsWith(CellText, "(")
							AND StrEndsWith(CellText, ")") Then 
							
							CellText = StrReplace(CellText, "(", "");
							CellText = StrReplace(CellText, ")", "");
							
							Number = TypeDescriptionNumber.AdjustValue(CellText);
							If Number > 0 Then 
								Number = -Number;
							EndIf;
						Else
							Number = TypeDescriptionNumber.AdjustValue(CellText);
						EndIf;
					Else
						Continue;
					EndIf;
					Result.FilledCellsCount = Result.FilledCellsCount + 1;
					If TypeOf(Number) = Type("Number") Then
						Result.NumericCellsCount = Result.NumericCellsCount + 1;
						Result.Amount = Result.Amount + Number;
						If Result.NumericCellsCount = 1 Then
							Result.Minimum  = Number;
							Result.Maximum = Number;
						Else
							Result.Minimum  = Min(Number,  Result.Minimum);
							Result.Maximum = Max(Number, Result.Maximum);
						EndIf;
					EndIf;
				EndIf;
			EndDo;
		EndDo;
	EndDo;
	
	If Result.NumericCellsCount > 0 Then
		Result.Mean = Result.Amount / Result.NumericCellsCount;
	EndIf;
	
	Return Result;
	
EndFunction

// Generates the presentation of scheduled job schedule.
//
// Parameters:
//   Schedule - JobSchedule - a schedule.
//
// Returns:
//   String - schedule presentation.
//
Function SchedulePresentation(Schedule) Export
	SchedulePresentation = String(Schedule);
	SchedulePresentation = Upper(Left(SchedulePresentation, 1)) + Mid(SchedulePresentation, 2);
	SchedulePresentation = StrReplace(StrReplace(SchedulePresentation, "  ", " "), " ]", "]") + ".";
	Return SchedulePresentation;
EndFunction

#EndRegion

