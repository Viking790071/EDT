#Region EventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	Ref = Parameters.Ref;
	
	Items.NoVersions.Title = StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Предыдущие версии отсутствуют: ""%1"".'; en = 'Earlier versions are not available: %1.'; pl = 'Brak poprzednich wersji: ""%1"".';es_ES = 'Versiones previas están faltando: ""%1"".';es_CO = 'Versiones previas están faltando: ""%1"".';tr = 'Önceki sürümler eksik: ""%1"".';it = 'Nessuna versione precedente: ""%1"".';de = 'Frühere Versionen fehlen: ""%1"".'"), String(Ref));
	RefreshVersionList();
	
	GoToVersionAllowed = Users.IsFullUser() AND Not ReadOnly;
	Items.GoToVersion.Visible = GoToVersionAllowed;
	Items.VersionsTreeContextMenuGoToVersion.Visible = GoToVersionAllowed;
	Items.TechnicalInfoAboutObjectChanges.Visible = GoToVersionAllowed;
	
	Attributes = NStr("ru = 'Все'; en = 'All'; pl = 'Wszyscy';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'")
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	SetAvailability();
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AttributesStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	NotifyDescription = New NotifyDescription("OnSelectAttribute", ThisObject);
	OpenForm("InformationRegister.ObjectsVersions.Form.SelectObjectAttributes", New Structure(
		"Ref,Filter", Ref, Filter.UnloadValues()), , , , , NotifyDescription);
EndProcedure

&AtClient
Procedure EventLogClick(Item)
	EventLogFilter = New Structure;
	EventLogFilter.Insert("Data", Ref);
	EventLogClient.OpenEventLog(EventLogFilter);
EndProcedure

#EndRegion

#Region FormTableEventItemHandlersVersionList

&AtClient
Procedure VersionTreeSelection(Item, RowSelected, Field, StandardProcessing)
	OpenReportOnObjectVersion();
EndProcedure

&AtClient
Procedure VersionTreeOnActivateRow(Item)
	SetAvailability();
EndProcedure

&AtClient
Procedure VersionTreeCommentOnChange(Item)
	CurrentData = Items.VersionsTree.CurrentData;
	If CurrentData <> Undefined Then
		AddCommentToVersion(Ref, CurrentData.VersionNumber, CurrentData.Comment);
	EndIf;
EndProcedure

&AtClient
Procedure VersionTreeBeforeChangeStart(Item, Cancel)
	If Not CanEditComments(Item.CurrentData.VersionAuthor) Then
		Cancel = True;
	EndIf;
EndProcedure


#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure OpenObjectVersion(Command)
	
	OpenReportOnObjectVersion();
	
EndProcedure

&AtClient
Procedure GoToVersion(Command)
	
	GoToSelectedVersion();
	
EndProcedure

&AtClient
Procedure GenerateReportOnChanges(Command)
	
	SelectedRows = Items.VersionsTree.SelectedRows;
	VersionsToCompare = GenerateSelectedVersionList(SelectedRows);
	
	If VersionsToCompare.Count() < 2 Then
		ShowMessageBox(, NStr("ru = 'Для формирования отчета по изменениям необходимо выбрать хотя бы две версии.'; en = 'To generate a change report, select at least two versions.'; pl = 'Aby utworzyć sprawozdanie o zmianach, wybierz przynajmniej dwie wersje.';es_ES = 'Para generar un informe de cambios, seleccionar como mínimo dos versiones.';es_CO = 'Para generar un informe de cambios, seleccionar como mínimo dos versiones.';tr = 'Değişiklikler hakkında bir rapor oluşturmak için en az iki versiyon seçin.';it = 'Per generare un report sulle modifiche, seleziona almeno due versioni.';de = 'Um einen Bericht über Änderungen zu generieren, wählen Sie mindestens zwei Versionen aus.'"));
		Return;
	EndIf;
	
	OpenReportForm(VersionsToCompare);
	
EndProcedure

&AtClient
Procedure Update(Command)
	RefreshVersionList();
EndProcedure

#EndRegion

#Region Private

&AtServer
Function GenerateVersionTable()
	
	If ObjectsVersioning.HasRightToReadObjectVersionData() Then
		SetPrivilegedMode(True);
	EndIf;
	
	VersionNumbers = New Array;
	If Filter.Count() > 0 Then
		VersionNumbers = VersionNumbersWithChangesInSelectedAttributes();
	EndIf;
	
	QueryText = 
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.VersionAuthor AS VersionAuthor,
	|	ObjectsVersions.VersionDate AS VersionDate,
	|	ObjectsVersions.Comment AS Comment,
	|	ObjectsVersions.Checksum,
	|	ObjectsVersions.HasVersionData,
	|	&NoFilter
	|		OR ObjectsVersions.VersionNumber IN (&VersionNumbers) AS MatchesFilter,
	|	ObjectsVersions.VersionOwner,
	|	ObjectsVersions.ObjectVersionType,
	|	ObjectsVersions.Node
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("NoFilter", Filter.Count() = 0);
	Query.SetParameter("VersionNumbers", VersionNumbers);
	Query.SetParameter("Ref", Ref);
	
	VersionTable = Query.Execute().Unload();
	
	VersionTable.Columns.Add("CurrentVersion", New TypeDescription("Boolean"));
	
	CustomVersions = VersionTable.FindRows(New Structure("ObjectVersionType", Enums.ObjectVersionTypes.ChangedByUser));
	If CustomVersions.Count() > 0 Then
		CustomVersions[0].HasVersionData = True;
		CustomVersions[0].CurrentVersion = True;
		CurrentVersionNumber = CustomVersions[0].VersionNumber;
	EndIf;
	
	For Index = 1 To CustomVersions.Count() - 1 Do
		If Not CustomVersions[Index].HasVersionData Then
			If IsBlankString(CustomVersions[Index].Checksum) Or CustomVersions[Index].Checksum = CustomVersions[Index-1].Checksum Then
				CustomVersions[Index].HasVersionData = CustomVersions[Index-1].HasVersionData;
			EndIf;
		EndIf;
	EndDo;
	
	ThisInfobaseName = ThisInfobaseName();
	For Each Version In VersionTable Do
		If IsBlankString(Version.Node) Then
			Version.Node = ThisInfobaseName;
		EndIf;
	EndDo;
	
	Result = VersionTable.Copy(VersionTable.FindRows(New Structure("MatchesFilter", True)),
		"VersionNumber, VersionAuthor, VersionDate, Comment, HasVersionData, VersionOwner, Node, CurrentVersion");
		
	Return Result;
	
EndFunction

&AtClient
Procedure GoToSelectedVersion(CancelPosting = False)
	
	CurrentData = Items.VersionsTree.CurrentData;
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	VersionNumberPresentation = CurrentData.VersionNumberPresentation;
	Result = GoToVersionServer(Ref, CurrentData.VersionNumber, CancelPosting);
	
	If Result = "RecoveryError" Then
		CommonClientServer.MessageToUser(ErrorMessageText);
	ElsIf Result = "PostingError" Then
		QuestionText = StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Не удается восстановить версию документа. Причина:
				|%1
				| Отменить проведение документа и восстановить эту версию?'; 
				|en = 'Cannot restore the document version. Reason:
				|%1
				|Do you want to unpost the document and restore this version?'; 
				|pl = 'Nie można przywrócić wersji dokumentu. Przyczyna:
				|%1
				|Czy chcesz anulować zatwierdzenie dokumentu i przywrócić tę wersję?';
				|es_ES = 'Ha ocurrido un error al restablecer la versión del documento. Motivo:
				|%1
				|¿Quiere cancelar el envío del documento y restablecer esta versión?';
				|es_CO = 'Ha ocurrido un error al restablecer la versión del documento. Motivo:
				|%1
				|¿Quiere cancelar el envío del documento y restablecer esta versión?';
				|tr = 'Belge sürümü geri yüklenemiyor. Nedeni:
				|%1
				|Belgenin kaydedilmesini geri alıp bu sürümü geri yüklemek istiyor musunuz?';
				|it = 'Impossibile ripristinare la versione del documento. Motivo:
				|%1
				|Annullare la pubblicazione del documento e ripristinare questa versione?';
				|de = 'Fehler beim Wiederherstellen der Dokumentenversion. Grund:
				|%1
				|Möchten Sie Buchen des Dokuments aufheben und diese Version wiederherstellen?'"),
			ErrorMessageText);
			
		NotifyDescription = New NotifyDescription("GoToSelectedVersionQuestionAsked", ThisObject);
		Buttons = New ValueList;
		Buttons.Add("Seek", NStr("ru = 'Перейти'; en = 'Navigate'; pl = 'Przejdź';es_ES = 'Navegar';es_CO = 'Navegar';tr = 'Geçiş yapın';it = 'Navigare';de = 'Navigieren'"));
		Buttons.Add(DialogReturnCode.Cancel);
		ShowQueryBox(NotifyDescription, QuestionText, Buttons);
	Else //Result = "RestoringComplete"
		NotifyChanged(Ref);
		If FormOwner <> Undefined Then
			Try
				FormOwner.Read();
			Except
				// Do nothing if the form has no Read() method.
			EndTry;
		EndIf;
		ShowUserNotification(
			StringFunctionsClientServer.SubstituteParametersToString(NStr("ru = 'Восстановлена версия № %1.'; en = 'Version No.%1 is restored'; pl = 'Przywrócono wersję Nr %1.';es_ES = 'Versión restablecida № %1.';es_CO = 'Versión restablecida № %1.';tr = '%1 sayılı sürüm geri yüklendi.';it = 'Versione No.%1 è stata ripristinata';de = 'Wiederhergestellte Version Nr. %1.'"), VersionNumberPresentation),
			GetURL(Ref),
			String(Ref),
			PictureLib.Information32);
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToSelectedVersionQuestionAsked(QuestionResult, AdditionalParameters) Export
	If QuestionResult <> "Seek" Then
		Return;
	EndIf;
	
	GoToSelectedVersion(True);
EndProcedure

&AtServer
Function GoToVersionServer(Ref, VersionNumber, UndoPosting = False)
	ErrorMessageText = "";
	Result = ObjectsVersioning.GoToVersionServer(Ref, VersionNumber, ErrorMessageText, UndoPosting);
	
	RefreshVersionList();
	
	Return Result;
EndFunction

&AtClient
Procedure OpenReportOnObjectVersion()
	
	VersionsToCompare = New ValueList;
	VersionsToCompare.Add(Items.VersionsTree.CurrentData.VersionNumber, Items.VersionsTree.CurrentData.VersionNumberPresentation);
	OpenReportForm(VersionsToCompare);
	
EndProcedure

&AtClient
Procedure OpenReportForm(VersionsToCompare)
	
	ReportParameters = New Structure;
	ReportParameters.Insert("Ref", Ref);
	ReportParameters.Insert("VersionsToCompare", VersionsToCompare);
	
	OpenForm("InformationRegister.ObjectsVersions.Form.ObjectVersionsReport",
		ReportParameters,
		ThisObject,
		UUID);
	
EndProcedure

&AtClient
Function GenerateSelectedVersionList(SelectedRows)
	
	VersionsToCompare = New ValueList;
	
	For Each SelectedRowNumber In SelectedRows Do
		RowData = Items.VersionsTree.RowData(SelectedRowNumber);
		VersionsToCompare.Add(RowData.VersionNumber, RowData.VersionNumberPresentation);
	EndDo;
	
	VersionsToCompare.SortByValue(SortDirection.Asc);
	
	If VersionsToCompare.Count() = 1 Then
		If VersionsToCompare.FindByValue(CurrentVersionNumber) = Undefined Then
			CurrentVersion = CurrentVersion(VersionsTree);
			If CurrentVersion = Undefined Then
				VersionsToCompare.Add(CurrentVersionNumber);
			Else
				VersionsToCompare.Add(CurrentVersion.VersionNumber, CurrentVersion.VersionNumberPresentation);
			EndIf;
		EndIf;
	EndIf;
	
	Return VersionsToCompare;
	
EndFunction

&AtClient
Function CurrentVersion(VersionList)
	For Each Version In VersionList.GetItems() Do
		If Version.CurrentVersion Then
			Result = Version;
		Else
			Result = CurrentVersion(Version);
		EndIf;
		If Result <> Undefined Then
			Return Result;
		EndIf;
	EndDo;
	Return Undefined;
EndFunction

&AtClient
Procedure SetAvailability()
	
	OneVersionSelected = Items.VersionsTree.SelectedRows.Count() = 1;
	
	Items.OpenVersion.Enabled = OneVersionSelected;
	Items.VersionsTreeContextMenuOpenVersion.Enabled = OneVersionSelected;
	
	Items.GoToVersion.Enabled = OneVersionSelected;
	Items.VersionsTreeContextMenuGoToVersion.Enabled = OneVersionSelected;
	
	Items.Compare.Enabled = Items.VersionsTree.SelectedRows.Count() > 0;
	
EndProcedure

&AtClient
Procedure OnSelectAttribute(SelectionResult, AdditionalParameters) Export
	If SelectionResult = Undefined Then
		Return;
	EndIf;
	
	Attributes = SelectionResult.SelectedItemsPresentation;
	Filter.LoadValues(SelectionResult.SelectedAttributes);
	RefreshVersionList();
EndProcedure

&AtServer
Procedure RefreshVersionList()
	
	VersionTable = GenerateVersionTable();
	HasVersions = VersionTable.Count() > 0;
	
	If HasVersions Then
		Items.MainPage.CurrentPage = Items.SelectVersionsToCompare;
	
		VersionTable.Sort("VersionOwner Asc, VersionNumber Desc");
		
		VersionHierarchy = FormAttributeToValue("VersionsTree");
		VersionHierarchy.Rows.Clear();
		
		ObjectsVersioning.FillVersionHierarchy(VersionHierarchy, VersionTable);
		ObjectsVersioning.NumberVersions(VersionHierarchy.Rows);
		
		ValueToFormAttribute(VersionHierarchy, "VersionsTree");
		
		VersionTable.GroupBy("Node");
		Items.VersionsTreeNode.Visible = VersionTable.Count() > 1 Or VersionTable.Count() = 1 AND VersionTable[0].Node <> ThisInfobaseName();
	Else
		Items.MainPage.CurrentPage = Items.NoVersionsToCompare;
	EndIf;
	
	Items.ActionsWithVersion.Enabled = HasVersions;
	Items.Attributes.Enabled = HasVersions;
	
EndProcedure

&AtClient
Procedure AttributesClearing(Item, StandardProcessing)
	StandardProcessing = False;
	Attributes = NStr("ru = 'Все'; en = 'All'; pl = 'Wszyscy';es_ES = 'Todo';es_CO = 'Todo';tr = 'Tümü';it = 'Tutti';de = 'Alle'");
	Filter.Clear();
	RefreshVersionList();
EndProcedure

&AtServer
Function VersionNumbersWithChangesInSelectedAttributes()
	QueryText =
	"SELECT
	|	ObjectsVersions.VersionNumber AS VersionNumber,
	|	ObjectsVersions.HasVersionData,
	|	ObjectsVersions.ObjectVersion AS Data
	|FROM
	|	InformationRegister.ObjectsVersions AS ObjectsVersions
	|WHERE
	|	ObjectsVersions.ObjectVersionType = VALUE(Enum.ObjectVersionTypes.ChangedByUser)
	|	AND ObjectsVersions.Object = &Ref
	|
	|ORDER BY
	|	VersionNumber DESC";
	
	Query = New Query(QueryText);
	Query.SetParameter("Ref", Ref);
	StoredVersions = Query.Execute().Unload();
	
	VersionData = New ValueStorage(ObjectsVersioning.SerializeObject(Ref.GetObject()), New Deflation(9));
	CurrentVersion = StoredVersions[0];
	CurrentVersion.Data = VersionData;
	CurrentVersion.VersionNumber = ObjectsVersioning.LastVersionNumber(Ref);
	CurrentVersion.HasVersionData = True;
	
	For Each VersionDetails In StoredVersions Do
		If Not VersionDetails.HasVersionData Then
			VersionDetails.Data = VersionData;
		Else
			VersionData = VersionDetails.Data;
		EndIf;
	EndDo;
	
	Result = New Array;
	Result.Add(StoredVersions[StoredVersions.Count() - 1].VersionNumber);
	
	ObjectData = StoredVersions[0].Data.Get();
	If TypeOf(ObjectData) = Type("Structure") Then
		ObjectData = ObjectData.Object;
	EndIf;
	CurrentVersion = ObjectsVersioning.XMLObjectPresentationParsing(ObjectData, Ref);
	For RowNumber = 1 To StoredVersions.Count() - 1 Do
		VersionDetails = StoredVersions[RowNumber];
		
		ObjectData = VersionDetails.Data.Get();
		If TypeOf(ObjectData) = Type("Structure") Then
			ObjectData = ObjectData.Object;
		EndIf;
		PreviousVersion = ObjectsVersioning.XMLObjectPresentationParsing(ObjectData, Ref);
		
		If AttributesChanged(CurrentVersion, PreviousVersion, Filter.UnloadValues()) Then
			Result.Add(StoredVersions[RowNumber - 1].VersionNumber);
		EndIf;
		CurrentVersion =PreviousVersion;
	EndDo;
	
	Return Result;
EndFunction

&AtServer
Function AttributesChanged(CurrentVersion, PreviousVersion, AttributesList)
	For Each Attribute In AttributesList Do
		TabularSectionName = Undefined;
		AttributeName = Attribute;
		If StrFind(AttributeName, ".") > 0 Then
			NameParts = StrSplit(AttributeName, ".", False);
			If NameParts.Count() > 1 Then
				TabularSectionName = NameParts[0];
				AttributeName = NameParts[1];
			EndIf;
		EndIf;
		
		// Tabular section attribute change check.
		If TabularSectionName <> Undefined Then
			CurrentTabularSection = CurrentVersion.TabularSections[TabularSectionName];
			PreviousTabularSection = PreviousVersion.TabularSections[TabularSectionName];
			
			// Tabular section is missing.
			If CurrentTabularSection = Undefined Or PreviousTabularSection = Undefined Then
				Return Not CurrentTabularSection = Undefined AND PreviousTabularSection = Undefined;
			EndIf;
			
			// If the number of tabular section rows is changed.
			If CurrentTabularSection.Count() <> PreviousTabularSection.Count() Then
				Return True;
			EndIf;
			
			// attribute is missing
			CurrentAttributeExists = CurrentTabularSection.Columns.Find(AttributeName) <> Undefined;
			PreviousAttributeExists = PreviousTabularSection.Columns.Find(AttributeName) <> Undefined;
			If CurrentAttributeExists <> PreviousAttributeExists Then
				Return True;
			EndIf;
			If Not CurrentAttributeExists Then
				Return False;
			EndIf;
			
			// comparison by rows
			For RowNumber = 0 To CurrentTabularSection.Count() - 1 Do
				If CurrentTabularSection[RowNumber][AttributeName] <> PreviousTabularSection[RowNumber][AttributeName] Then
					Return True;
				EndIf;
			EndDo;
			
			Return False;
		EndIf;
		
		// header attribute check
		
		CurrentAttribute = CurrentVersion.Attributes.Find(AttributeName, "AttributeDescription");
		CurrentAttributeExists = CurrentAttribute <> Undefined;
		CurrentAttributeValue = Undefined;
		If CurrentAttributeExists Then
			CurrentAttributeValue = CurrentAttribute.AttributeValue;
		EndIf;
		
		PreviousAttribute = PreviousVersion.Attributes.Find(AttributeName, "AttributeDescription");
		PreviousAttributeExists = PreviousAttribute <> Undefined;
		PreviousAttributeValue = Undefined;
		If PreviousAttributeExists Then
			PreviousAttributeValue = PreviousAttribute.AttributeValue;
		EndIf;
		
		If CurrentAttributeExists <> PreviousAttributeExists
			Or CurrentAttributeValue <> PreviousAttributeValue Then
			Return True;
		EndIf;
	EndDo;
	
	Return False;
EndFunction

&AtServerNoContext
Procedure AddCommentToVersion(ObjectRef, VersionNumber, Comment);
	ObjectsVersioning.AddCommentToVersion(ObjectRef, VersionNumber, Comment);
EndProcedure

&AtServerNoContext
Function CanEditComments(VersionAuthor)
	Return Users.IsFullUser()
		Or VersionAuthor = Users.CurrentUser();
EndFunction

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	// Missing version data.
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.HasVersionData");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
	
	// Rejected versions
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.Rejected");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.InaccessibleCellTextColor);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
	// Current version
	
	Item = ConditionalAppearance.Items.Add();
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("VersionsTree.CurrentVersion");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Font = New Font(Items.VersionsTreeVersionNumberPresentation.Font, , , True, , , , );
	
	Item.Appearance.SetParameterValue("Font", Font);
	
	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.VersionsTree.Name);
	
EndProcedure

&AtServer
Function ThisInfobaseName()
	Return NStr("ru = 'Эта программа'; en = 'This application'; pl = 'Ta aplikacja';es_ES = 'Esta aplicación';es_CO = 'Esta aplicación';tr = 'Bu uygulama';it = 'Questa applicazione';de = 'Diese Anwendung'");
EndFunction

#EndRegion
