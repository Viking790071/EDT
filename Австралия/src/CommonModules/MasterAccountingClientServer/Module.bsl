
#Region Public

Function GetExtDimensionFieldName(Index = 1, Suffix = "", Field = "") Export
	
	Return StringFunctionsClientServer.SubstituteParametersToString("ExtDimension%1%2%3", Field, Suffix, Index);
	
EndFunction

Function GetExtDimensionFieldPresentation(Index = 1, Suffix = "") Export
	
	Return StrTemplate(NStr("en = 'Analytical dimension %1 %2'; ru = 'Аналитическое измерение %1 %2';pl = 'Wymiiar analityczny %1 %2';es_ES = 'Dimensión analítica %1%2';es_CO = 'Dimensión analítica %1%2';tr = 'Analitik boyut %1 %2';it = 'Dimensione analitica %1 %2';de = 'Analytische Messung %1 %2'"), Index, Suffix);
	
EndFunction

Function GetExtDimensionPresentation(PresentationString) Export
	
	Return StrTemplate("<%1>", PresentationString);
	
EndFunction

Function AddEntry(Table, DefaultData, ObjectType) Export
	
	NewEntryParameters	= GetNewEntryParameters();
	EntryNumber			= GetNextEntryNumber(Table);
	
	DrLine = Table.Add();
	DrLine.EntryNumber		= EntryNumber;
	DrLine.EntryLineNumber	= 1;
	
	If ObjectType = "AccountingEntriesTemplates" Then
		
		DrLine.Mode = NewEntryParameters.Mode;
		DrLine.DrCr = NewEntryParameters.Dr;
		
	ElsIf ObjectType = "AccountingTransaction" 
		Or ObjectType = "DocumentAccountingEntries"
		Or ObjectType = "AccountingEntriesManagement" Then
		
		DrLine.RecordType		= AccountingRecordType.Debit;
		DrLine.RecordSetPicture = 1;
		DrLine.Active			= True;
		DrLine.Company			= DefaultData.Company;
		DrLine.Period			= DefaultData.Period;
		
	EndIf;
	
	DrLine.NumberPresentation = StrTemplate("%1/%2", EntryNumber, 1);
	
	CrLine = Table.Add();
	CrLine.EntryNumber		= EntryNumber;
	CrLine.EntryLineNumber	= 2;
	If ObjectType = "AccountingEntriesTemplates" Then
		
		CrLine.Mode = NewEntryParameters.Mode;
		CrLine.DrCr = NewEntryParameters.Cr;
		
	ElsIf ObjectType = "AccountingTransaction" 
		Or ObjectType = "DocumentAccountingEntries"
		Or ObjectType = "AccountingEntriesManagement" Then
		
		CrLine.RecordType		= AccountingRecordType.Credit;
		CrLine.RecordSetPicture = 2;
		CrLine.Active			= True;
		CrLine.Company			= DefaultData.Company;
		CrLine.Period			= DefaultData.Period;
		
	EndIf;
	CrLine.NumberPresentation = StrTemplate("%1/%2", EntryNumber, 2);
	
	Return DrLine.GetID();
	
EndFunction

Function AddEntryLine(Table, DefaultData, ObjectType) Export
	
	NewEntryParameters	= GetNewEntryParameters();
	CurrentIndex		= DefaultData.CurrentIndex;
	CurrentLine			= Table.Get(CurrentIndex);
	
	NewLine	= Table.Insert(CurrentIndex + 1);
	NewLine.EntryNumber		= CurrentLine.EntryNumber;
	NewLine.EntryLineNumber = CurrentLine.EntryLineNumber + 1;
	
	If ObjectType = "AccountingEntriesTemplates" Then
		
		NewLine.Mode = NewEntryParameters.Mode;
		NewLine.DrCr = CurrentLine.Cr;
		
	ElsIf ObjectType = "AccountingTransaction" 
		Or ObjectType = "DocumentAccountingEntries" Then
		
		NewLine.RecordType		= CurrentLine.RecordType;
		NewLine.RecordSetPicture = ?(CurrentLine.RecordType = AccountingRecordType.Debit, 1, 2);
		NewLine.Active			= True;
		NewLine.Company			= DefaultData.Company;
		NewLine.Period			= DefaultData.Period;
		NewLine.LineNumber 		= CurrentLine.LineNumber + 1;
	
	ElsIf ObjectType = "AccountingEntriesManagement" Then
		
		NewLine.RecordType		= CurrentLine.RecordType;
		NewLine.RecordSetPicture = ?(CurrentLine.RecordType = AccountingRecordType.Debit, 1, 2);
		NewLine.Active			= True;
		NewLine.Company			= DefaultData.Company;
		NewLine.Period			= DefaultData.Period;
	
	EndIf;
	
	RenumerateEntryLineNumbers(Table, CurrentLine.EntryNumber);
		
	Return NewLine.GetID();
	
EndFunction

Procedure MoveEntriesUpDown(Table, DefaultData, ObjectType) Export
	
	If ObjectType = "AccountingEntriesTemplates" Then
		
		RecordTypeFieldName = "DrCr";	
		SortParameter = "EntryNumber, DrCr Desc";
		
	ElsIf ObjectType = "AccountingTransaction" 
		Or ObjectType = "DocumentAccountingEntries"
		Or ObjectType = "AccountingEntriesManagement" Then 
		
		RecordTypeFieldName = "RecordType";	
		SortParameter = "EntryNumber, RecordType Desc";
		
	EndIf;
	
	RowsArray = DefaultData.RowsArray;
	Direction = DefaultData.Direction;
	
	CheckResult = CheckRowsInOneEntry(Table, RowsArray);
	
	If CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.Property("ConsecutiveEntries") 
		And CheckResult.WholeEntry 
		And CheckResult.ConsecutiveEntries 
		And RowsArray.Count() > 1 Then
		
		MoveSeveralEntries(Table, RowsArray, Direction);
		Table.Sort(SortParameter);
		RenumerateEntriesTabSection(Table, False);
		
	ElsIf CheckResult.Property("SeveralEntries") 
		Or CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() > 1 Then
		
		Action = NStr("en = 'move'; ru = 'переместить';pl = 'przenieś';es_ES = 'Trasladar';es_CO = 'Trasladar';tr = 'taşı';it = 'sposta';de = 'verschieben'");
		MessageText = MessagesToUserClientServer.GetCopyMoveLinesErrorText(Action);
		CommonClientServer.MessageToUser(MessageText);
		
		Return;
		
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		MoveEntry(Table, RowsArray, Direction);
		Table.Sort(SortParameter);
		RenumerateEntriesTabSection(Table, False);
	
	ElsIf CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry And RowsArray.Count() = 1 Then
		
		MoveRows(Table, RowsArray, Direction, ObjectType);
		Table.Sort(SortParameter);
		RenumerateEntriesTabSection(Table, False);
		
	Else
		Return;
	EndIf;
	
EndProcedure

Function CopyEntriesRows(Table, DefaultData, ObjectType) Export
	
	If ObjectType = "AccountingEntriesTemplates" Then
		
		RecordTypeFieldName = "DrCr";
		SortParameter = "EntryNumber, DrCr Desc";
		
	ElsIf ObjectType = "AccountingTransaction"
		Or ObjectType = "DocumentAccountingEntries"
		Or ObjectType = "AccountingEntriesManagement" Then 
		
		RecordTypeFieldName = "RecordType";
		SortParameter = "EntryNumber, RecordType Desc";
		
	EndIf;
	
	RowsArray = DefaultData.RowsArray;
	
	CheckResult = CheckRowsInOneEntry(Table, RowsArray);
	
	If CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And Not CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		Action = NStr("en = 'copy'; ru = 'скопировать';pl = 'kopiuj';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'kopyala';it = 'copia';de = 'kopieren'");
		MessageText = MessagesToUserClientServer.GetCopyMoveLinesErrorText(Action);
		CommonClientServer.MessageToUser(MessageText);
		
		Return Undefined;
		
	ElsIf CheckResult.Property("WholeEntry") 
		And Not CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		Action = NStr("en = 'copy'; ru = 'скопировать';pl = 'kopiuj';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'kopyala';it = 'copia';de = 'kopieren'");
		MessageText = MessagesToUserClientServer.GetCopyMoveLinesErrorText(Action);
		CommonClientServer.MessageToUser(MessageText);
		
		Return Undefined;
		
	ElsIf CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.Property("ConsecutiveEntries") 
		And CheckResult.WholeEntry 
		And Not CheckResult.ConsecutiveEntries 
		And RowsArray.Count() > 1 Then
		
		Action = NStr("en = 'copy'; ru = 'скопировать';pl = 'kopiuj';es_ES = 'COPIA';es_CO = 'COPIA';tr = 'kopyala';it = 'copia';de = 'kopieren'");
		MessageText = MessagesToUserClientServer.GetCopyMoveLinesErrorText(Action);
		CommonClientServer.MessageToUser(MessageText);
		
		Return Undefined;
		
	ElsIf CheckResult.Property("SeveralEntries") 
		And CheckResult.Property("WholeEntry") 
		And CheckResult.WholeEntry 
		And RowsArray.Count() > 1 Then
		
		CurrentRowLineNumber = Undefined;
		CurrentEntryNumber = RowsArray[0].EntryNumber;
		EntryNumber = 0;
		For Each RowToCopy In RowsArray Do
			
			EntryNumber = ?(CurrentEntryNumber = RowToCopy.EntryNumber, EntryNumber, EntryNumber + 0.01);
			
			NewLine = Table.Add();
			FillPropertyValues(NewLine, RowToCopy, , "EntryNumber");
			NewLine.EntryNumber = EntryNumber;
			
			CurrentRowLineNumber = ?(CurrentRowLineNumber = Undefined, NewLine.GetID(), CurrentRowLineNumber);
		
			CurrentEntryNumber = RowToCopy.EntryNumber;
		
		EndDo;
		
		RenumerateEntriesTabSection(Table);
		
		Return CurrentRowLineNumber;
		
	ElsIf RowsArray.Count() = 1 And CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		NewEntryParameters = GetNewEntryParameters();
		EntryNumber = GetNextEntryNumber(Table);
		
		NewLine = Table.Add();
		
		RowToCopy = RowsArray[0];
		FillPropertyValues(NewLine, RowToCopy);
		
		NewLine.EntryNumber			= EntryNumber;
		NewLine.EntryLineNumber		= 1;
		NewLine.NumberPresentation	= StrTemplate("%1/%2", EntryNumber, 1);
		
		CurrentRowLineNumber	 = NewLine.GetID();
		
		Return CurrentRowLineNumber;
		
	ElsIf RowsArray.Count() = 1 And CheckResult.Property("WholeEntry") And Not CheckResult.WholeEntry Then
		
		RowToCopy	= RowsArray[0];
		NewLine		= Table.Add();
		
		FillPropertyValues(NewLine, RowToCopy);
		
		RenumerateEntryLineNumbers(Table, NewLine.EntryNumber, True);
		
		CurrentRowLineNumber	 = NewLine.GetID();
		
		Return CurrentRowLineNumber;
			
	ElsIf CheckResult.Property("WholeEntry") And CheckResult.WholeEntry Then
		
		CurrentRowLineNumber = Undefined;
		
		For Each RowToCopy In RowsArray Do
			
			NewLine = Table.Add();
			FillPropertyValues(NewLine, RowToCopy, , "EntryNumber");
			
			CurrentRowLineNumber = ?(CurrentRowLineNumber = Undefined, NewLine.GetID(), CurrentRowLineNumber);
		
		EndDo;
		
		RenumerateEntriesTabSection(Table);
		
		Return CurrentRowLineNumber;
		
	EndIf;
	
EndFunction

Procedure RenumerateEntriesTabSection(Table, Sort = False) Export
	
	If Sort Then
		Table.Sort("EntryNumber, EntryLineNumber");
	EndIf;
	
	EntriesNumbers = GetEntriesNumber(Table);
	
	EntriesIndex	= 1;
	CalculatedRows	= New Array;
	
	For Each EntriesNumber In EntriesNumbers Do
		
		RenumerateEntry(Table, EntriesNumber, EntriesIndex, CalculatedRows);
		
		EntriesIndex = EntriesIndex + 1;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

Function GetNewEntryParameters()
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Mode"	, PredefinedValue("Enum.AccountingEntriesDataSourceModes.Separate"));
	ParametersStructure.Insert("Dr"		, PredefinedValue("Enum.DebitCredit.Dr"));
	ParametersStructure.Insert("Cr"		, PredefinedValue("Enum.DebitCredit.Cr"));
	
	Return ParametersStructure;
	
EndFunction

Function GetNextEntryNumber(Table)
	
	MaxEntryIndex = 0;
	
	For Each Row In Table Do
		If Row.EntryNumber > MaxEntryIndex Then
			MaxEntryIndex = Row.EntryNumber;
		EndIf;
	EndDo;
	
	Return MaxEntryIndex + 1;
	
EndFunction

Procedure RenumerateEntryLineNumbers(Table, EntryNumber, Sort = False)
	
	If Sort Then
		Table.Sort("EntryNumber, EntryLineNumber");
	EndIf;
	
	EntriesLineIndex = 1;
	
	For Each Row In Table Do
		
		If Row.EntryNumber = EntryNumber Then
			
			Row.EntryLineNumber = EntriesLineIndex;
			EntriesLineIndex = EntriesLineIndex + 1;
			
			SetRowNumberPresentation(Row);
			
		EndIf;
	EndDo; 
	
EndProcedure

Procedure SetRowNumberPresentation(TSrow)

	TSRow.NumberPresentation = StrTemplate("%1/%2", TSrow.EntryNumber, TSrow.EntryLineNumber);
	
EndProcedure

Function CheckRowsInOneEntry(Table, RowsArray)

	EntryNumbersMap	= New Map;
	ReturnStructure	= New Structure;
	
	For Each TSRow In RowsArray Do
		
		NewValue = ?(EntryNumbersMap.Get(TSRow.EntryNumber) = Undefined, 1, EntryNumbersMap.Get(TSRow.EntryNumber)+1);
		EntryNumbersMap.Insert(TSRow.EntryNumber, NewValue);
		
	EndDo;
	
	WholeEntry = True;
	FirstEntryLine = Undefined;
	For Each MapItem In EntryNumbersMap Do
		
		EntryNumberFilter	= New Structure("EntryNumber", MapItem.Key);
		EntriesLines		= Table.FindRows(EntryNumberFilter);
		WholeEntry			= WholeEntry And EntriesLines.Count() = MapItem.Value;
		
		If FirstEntryLine = Undefined Then
			ConsecutiveEntries = True;
		ElsIf MapItem.Key = FirstEntryLine + 1 Then
			ConsecutiveEntries = ConsecutiveEntries And True;
		Else
			ConsecutiveEntries = False;
		EndIf;
		
		FirstEntryLine = MapItem.Key;
		
	EndDo;
	
	ReturnStructure.Insert("WholeEntry" , WholeEntry);
	
	If EntryNumbersMap.Count() = 1 Then
		ReturnStructure.Insert("EntryNumber", MapItem.Key);
	ElsIf EntryNumbersMap.Count() > 1 Then
		ReturnStructure.Insert("SeveralEntries", True);
		ReturnStructure.Insert("ConsecutiveEntries", ConsecutiveEntries);
	EndIf;
	
	Return ReturnStructure;
	
EndFunction

Procedure RenumerateEntry(Table, CurrentEntriesNumber, NewEntriesNumber, CalculatedRowsArray)
	
	CurrentEntryLines = GetEntriesLines(Table, CurrentEntriesNumber);
	
	EntryLineIndex = 1;
	
	For Each EntryLine In CurrentEntryLines Do
		
		If CalculatedRowsArray.Find(EntryLine) <> Undefined Then 
			Continue;
		EndIf;
		
		EntryLine.EntryNumber		= NewEntriesNumber;
		EntryLine.EntryLineNumber	= EntryLineIndex;
		
		EntryLineIndex = EntryLineIndex + 1;
		CalculatedRowsArray.Add(EntryLine);
		
		SetRowNumberPresentation(EntryLine);
	EndDo;
	
EndProcedure

Procedure MoveEntry(Table, RowsArray, Direction)

	For Each Row In RowsArray Do
		Row.EntryNumber = Row.EntryNumber + 1.1 * Direction;
	EndDo;
	
	RenumerateEntriesTabSection(Table, True);
	
EndProcedure

Procedure MoveSeveralEntries(Table, RowsArray, Direction)
	
	SelectedRowsIDs = New Array;
	For Each Row In RowsArray Do
		SelectedRowsIDs.Add(Row.GetID());
	EndDo;
	
	CountOfSelectedEntryLines = GetCountOfSelectedEntryLines(Table, SelectedRowsIDs);
	
	Multiplier = CountOfSelectedEntryLines + 0.1;
	
	EntriesNumbers = GetEntriesNumber(Table);
	
	FirstEntryNumber	= RowsArray[0].EntryNumber;
	LastEntryNumber		= RowsArray[RowsArray.UBound()].EntryNumber;
	CalculatedRowsArray	= New Array;
	
	For Each Row In RowsArray Do
		
		If CalculatedRowsArray.Find(Row.EntryNumber) <> Undefined Then 
			Continue;
		EndIf;
		
		EntriesArray	= GetEntriesLines(Table, Row.EntryNumber);
		IsFirstEntry	= Row.EntryNumber = FirstEntryNumber;
		IsLastEntry		= Row.EntryNumber = LastEntryNumber;
		
		For Each EntryRow In EntriesArray Do
			
			EntryRow.EntryNumber = EntryRow.EntryNumber + Multiplier * Direction;
			
			If IsFirstEntry And Direction < 0 
				Or IsLastEntry And Direction > 0 Then
				
				EntryRow.EntryNumber = EntryRow.EntryNumber - 0.2 * Direction;
				
			EndIf;
			
		EndDo;
		
		CalculatedRowsArray.Add(Row.EntryNumber);
		
	EndDo;
	
	RenumerateEntriesTabSection(Table, True);
	
EndProcedure

Procedure MoveRows(Table, RowsArray, Direction, ObjectType)

	MaxEntryNumber			= Table[Table.Count() - 1].EntryNumber;
	PreviousEntryNumber		= Min(Max(RowsArray[0].EntryNumber + Direction, 1), MaxEntryNumber);	// Previous could be actually next
	PrevEntriesLines		= GetEntriesLines(Table, PreviousEntryNumber);
	PrevEntriesLinesCount	= PrevEntriesLines.Count();
	LastRowIndex			= Table.Count();
	RowsCount				= RowsArray.Count();
	
	MaxEntryLineIndex = ?(PrevEntriesLinesCount > 0, PrevEntriesLines[PrevEntriesLinesCount - 1].EntryLineNumber, 0);
	
	AvailableToChangeEntryNumber = True;
	
	For Each Row In RowsArray Do
		
		If ObjectType = "AccountingEntriesTemplates" Then
			
			RowIndex = Table.IndexOf(Row);
			FirstLineEntry	= (Row.EntryLineNumber = 1 Or Row.DrCr <> Table[RowIndex - 1].DrCr);
			LastLineEntry	= (Row.EntryLineNumber = GetMaxEntryLineIndex(Table, Row.EntryNumber) Or Row.DrCr <> Table[RowIndex + 1].DrCr);
			BorderEntry		= (Row.EntryNumber = PreviousEntryNumber);
			
			SwitchEntryUp	= (FirstLineEntry And Direction < 0);
			SwitchEntryDown = (LastLineEntry And Direction > 0);
			
			AvailableToChangeEntryNumber = True;
			
		ElsIf ObjectType = "AccountingTransaction" 
			Or ObjectType = "DocumentAccountingEntries"
			Or ObjectType = "AccountingEntriesManagement" Then 
			
			RowIndex = Table.IndexOf(Row);
			FirstLineEntry	= (Row.EntryLineNumber = 1 Or Row.RecordType <> Table[RowIndex - 1].RecordType);
			LastLineEntry	= (Row.EntryLineNumber = GetMaxEntryLineIndex(Table, Row.EntryNumber) Or Row.RecordType <> Table[RowIndex + 1].RecordType);
			BorderEntry		= (Row.EntryNumber = PreviousEntryNumber);
			
			SwitchEntryUp	= (FirstLineEntry And Direction < 0);
			SwitchEntryDown = (LastLineEntry And Direction > 0);
			
		EndIf;
		
		If SwitchEntryUp And Not BorderEntry Then
			
			Row.EntryNumber		= PreviousEntryNumber;
			Row.EntryLineNumber	= MaxEntryLineIndex + 1;
			
		ElsIf SwitchEntryDown And Not BorderEntry Then
			
			Row.EntryNumber		= PreviousEntryNumber;
			Row.EntryLineNumber	= 0.01;
			
		ElsIf Not SwitchEntryUp And Not SwitchEntryDown Then
			Row.EntryLineNumber = Row.EntryLineNumber + (RowsCount + 0.01) * Direction;
		EndIf;

	EndDo;
	
	RenumerateEntriesTabSection(Table, True);
	
EndProcedure

Function GetMaxEntryLineIndex(Table, EntriesNumber)
	
	EntriesLines		= GetEntriesLines(Table, EntriesNumber);
	EntriesLinesCount	= EntriesLines.Count();
	
	Return EntriesLinesCount;
	
EndFunction

Function GetEntriesLines(Table, EntriesNumber)
	
	CurrentEntryFilter	= New Structure("EntryNumber", EntriesNumber);
	CurrentEntryLines	= Table.FindRows(CurrentEntryFilter);
	
	Return CurrentEntryLines;
	
EndFunction

Function GetEntriesNumber(Table)

	Return MasterAccountingServerCall.GetEntriesNumber(Table);
	
EndFunction

Function GetCountOfSelectedEntryLines(Table, SelectedRowsIDs) 
	
	SelectedRowsArray = New Array;
	
	For Each SelectedRowID In SelectedRowsIDs Do
		SelectedRowsArray.Add(Table.FindByID(SelectedRowID));
	EndDo;
	
	TempEntries = Table.Unload(SelectedRowsArray);
	TempEntries.GroupBy("EntryNumber");
	CountOfSelectedEntryLines = TempEntries.UnloadColumn("EntryNumber").Count();
	
	Return CountOfSelectedEntryLines;
	
EndFunction

#EndRegion