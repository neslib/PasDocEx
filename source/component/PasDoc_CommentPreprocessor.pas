unit PasDoc_CommentPreprocessor;

interface

function PreprocessComment(const Comment: String): String;

implementation

uses
  System.Classes,
  System.SysUtils;

procedure HandleHtmlTag(var S: String; const Index: Integer);
var
  I, J: Integer;
  TagName, UpperTagName, Text: String;
  TagType: (ttUnknown, ttBold, ttItalic, ttSource, ttCode, ttBr);
begin
  I := S.IndexOf('>', Index + 1);
  if (I = 0) then
    Exit;

  TagName := S.Substring(Index + 1, I - Index - 1);
  UpperTagName := TagName.ToUpper;
  if (UpperTagName = 'B') then
    TagType := ttBold
  else if (UpperTagName = 'I') then
    TagType := ttItalic
  else if (UpperTagName = 'SOURCE') then
    TagType := ttSource
  else if (UpperTagName = 'CODE') or (UpperTagName = 'TT') then
    TagType := ttCode
  else if (UpperTagName = 'BR') then
    TagType := ttBr
  else
    Exit;

  if (TagType = ttBr) then
    S := S.Remove(Index, TagName.Length + 2)
  else
  begin
    J := S.IndexOf('</' + TagName + '>', I + 1);
    if (J = 0) then
      Exit;

    Text := S.Substring(I + 1, J - I - 1);

    S := S.Remove(Index, J - Index + TagName.Length + 3);
  end;

  case TagType of
    ttBold:
      S := S.Insert(Index, '@bold(' + Text + ')');

    ttItalic:
      S := S.Insert(Index, '@italic(' + Text + ')');

    ttSource:
      S := S.Insert(Index, '@longcode(#' + Text.TrimRight + '#)');

    ttCode:
      S := S.Insert(Index, '@code(' + Text + ')');

    ttBr:
      S := S.Insert(Index, '@br');
  else
    Assert(False);
  end;
end;

function LineContainsText(const S: String; const Index: Integer;
  out NewIndex: Integer): Boolean; overload;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  I := Index;
  while (I < S.Length) do
  begin
    C := S.Chars[I];
    if (C = #10) then
      Break
    else if (C > ' ') then
    begin
      Result := True;
      Break;
    end;
    Inc(I);
  end;
  NewIndex := I;
end;

function LineContainsText(const S: String; const Index: Integer): Boolean; overload;
var
  Dummy: Integer;
begin
  Result := LineContainsText(S, Index, Dummy);
end;

procedure HandleParametersSection(var S: String; const SectionStart: Integer;
  const Index: Integer);
var
  I, ParamStart, DescStart: Integer;
  C: Char;
  StartOfLine: Boolean;
  Name, ParamName, Params: String;

  procedure HandleParam(const DescEnd: Integer);
  var
    Desc: String;
  begin
    if (ParamName = '') or (DescStart < 0) then
      Exit;

    Desc := S.Substring(DescStart, DescEnd - DescStart).Trim;
    Params := Params + '@param(' + ParamName + ' ' + Desc + ')' + sLineBreak;
  end;

begin
  { A Parameters section may look like this:

      Parameters:
        Foo: description of the Foo parameter
        spanning multiple lines.
        Bar: description of the Bar parameter
        Baz: description of the Baz parameter
          spanning multiple: lines.

    Notes:
    * The individual parameters may be indented, but that is not required.
    * A parameter description may span multiple lines. Additional lines may
      use an addition indent, but that is not requred.

    A parameter is identified as follows:
    * A parameter name starts at the beginning of a line and is terminated by
      a colon.
    * If the parameter name contains whitespace between characters, then it is
      not considered a new parameter, but a continuation of the description of
      the previous parameter (this is for that case the description contains a
      colon as well on additional lines).
    * If a line does not contain a colon, it is considered the continuation of
      the description of the previous parameter.
    * The section is terminated when a blank line or the end of the string is
      encountered or when another section is started. }
  I := Index;
  StartOfLine := False;
  ParamStart := -1;
  DescStart := -1;
  Params := '';
  while (I < S.Length) do
  begin
    C := S.Chars[I];
    case C of
      #10:
        begin
          if (StartOfLine) then
            { Blank line. End of section. }
            Break;
          StartOfLine := True;
          ParamStart := -1;
        end;

      'A'..'Z', 'a'..'z', '_':
        if (StartOfLine) and (ParamStart < 0) then
          ParamStart := I;

      '0'..'9', ' ': ; // Are allowed in parameter names (space is handled later)

      ':':
        begin
          if (ParamStart >= 0) then
          begin
            Name := S.Substring(ParamStart, I - ParamStart).Trim;
            { If name contains spaces, it is not a parameter. Trailing spaces
              are allowed before the colon. }
            if (Name.IndexOf(' ') < 0) then
            begin
              { Check if there is text after the colon. If not, this is actually
                the start of a new section. }
              if (LineContainsText(S, I + 1)) then
              begin
                HandleParam(ParamStart);
                ParamName := Name;
                DescStart := I + 1;
                ParamStart := -1;
              end
              else
              begin
                { Start of a new section. }
                I := ParamStart - 1;
                Break;
              end;
            end;
          end;
        end;
    else
      ParamStart := -1;
    end;

    if (C > ' ') then
      StartOfLine := False;

    Inc(I);
  end;
  HandleParam(I);

  if (Params <> '') then
  begin
    S := S.Remove(SectionStart, I - SectionStart + 1);
    S := S.Insert(SectionStart, Params + sLineBreak);
  end;
end;

function GetSectionText(var S: String; const SectionStart: Integer;
  const Index: Integer; out SectionEnd: Integer): String;
var
  I, WordStart: Integer;
  C: Char;
  StartOfLine: Boolean;
begin
  I := Index;
  StartOfLine := False;
  WordStart := -1;
  while (I < S.Length) do
  begin
    C := S.Chars[I];
    case C of
      #10:
        begin
          if (StartOfLine) then
            { Blank line. End of section. }
            Break;
          StartOfLine := True;
          WordStart := -1;
        end;

      'A'..'Z', 'a'..'z': // Can be beginning of new section
        if (StartOfLine) and (WordStart < 0) then
          WordStart := I;

      ':':
        begin
          { Check if there is text after the colon. If not, this is actually
            the start of a new section. }
          if (WordStart >= 0) and (not LineContainsText(S, I + 1)) then
          begin
            I := WordStart - 1;
            Break;
          end;
        end;
    else
      WordStart := -1;
    end;

    if (C > ' ') then
      StartOfLine := False;

    Inc(I);
  end;
  Result := S.Substring(Index, I - Index).Trim;
  SectionEnd := I;
end;

procedure HandleSimpleSection(var S: String; const SectionStart: Integer;
  const Index: Integer; const SectionName: String);
var
  Text: String;
  SectionEnd: Integer;
begin
  Text := GetSectionText(S, SectionStart, Index, SectionEnd);
  if (Text <> '') then
  begin
    S := S.Remove(SectionStart, SectionEnd - SectionStart + 1);
    S := S.Insert(SectionStart, '@' + SectionName + '(' + Text + ')' + sLineBreak);
  end;
end;

procedure HandleSeeAlsoSection(var S: String; const SectionStart: Integer;
  const Index: Integer);
var
  Text, Line, Link, SeeAlsos: String;
  SectionEnd: Integer;
  Lines, Links: TStringList;
begin
  { This section may look like this:
      SeeAlso:
        TgrObject, TgrObject.ReportMemoryUsage,
        TgrObject.ReportCircularReferences circular references, TgrInterfacedObject
    Multiple "see also" links may be separated by commas and/or new lines.
    A link may be followed by a space and link text. In that case, the link text
    will be used as the text for the hyperlink. }
  Text := GetSectionText(S, SectionStart, Index, SectionEnd).Trim;
  if (Text <> '') then
  begin
    SeeAlsos := '';
    Lines := TStringList.Create;
    try
      { Split text into multiple lines }
      Lines.Text := Text;
      for Line in Lines do
      begin
        Links := TStringList.Create;
        try
          { Split line into multiple links }
          Links.Delimiter := ',';
          Links.QuoteChar := #0;
          Links.StrictDelimiter := True;
          Links.DelimitedText := Line;
          for Link in Links do
            if (Link <> '') then
              SeeAlsos := SeeAlsos + '@seealso(' + Link.Trim + ')' + sLineBreak;
        finally
          Links.Free;
        end;
      end;
    finally
      Lines.Free;
    end;

    if (SeeAlsos <> '') then
    begin
      S := S.Remove(SectionStart, SectionEnd - SectionStart + 1);
      S := S.Insert(SectionStart, SeeAlsos);
    end;
  end;
end;

procedure HandleSection(var S: String; const SectionStart, SectionEnd: Integer;
  const Index: Integer);
var
  Section: String;
begin
  Section := S.Substring(SectionStart, SectionEnd - SectionStart).ToUpper;
  if (Section = 'PARAMETERS') then
    HandleParametersSection(S, SectionStart, Index)
  else if (Section = 'RETURN') or (Section = 'RETURNS') or (Section = 'RAISES') then
    HandleSimpleSection(S, SectionStart, Index, Section.ToLower)
  else if (Section = 'SEEALSO') then
    HandleSeeAlsoSection(S, SectionStart, Index)
end;

procedure HandleUnorderedList(var S: String; const Index: Integer);
var
  I, ItemStart: Integer;
  C: Char;
  StartOfLine, BlankLine, HasBlankLines, Compact: Boolean;
  Items, List: String;

  procedure HandleItem(const ItemEnd: Integer);
  var
    Item: String;
  begin
    if (ItemStart < 0) then
      Exit;

    if (HasBlankLines) then
      Compact := False;

    Item := S.Substring(ItemStart, ItemEnd - ItemStart).Trim;
    Items := Items + '@item(' + Item + ')' + sLineBreak;
  end;

begin
  I := Index;
  StartOfLine := True;
  BlankLine := False;
  HasBlankLines := False;
  Compact := True;
  Items := '';
  ItemStart := -1;
  while (I < S.Length) do
  begin
    C := S.Chars[I];
    case C of
      #10:
        begin
          if (StartOfLine) then
          begin
            BlankLine := True;
            HasBlankLines := True;
          end;
          StartOfLine := True;
        end;

      '*':
        if (StartOfLine) then
        begin
          HandleItem(I - 1);
          ItemStart := I + 1;
          BlankLine := False;
        end;
    else
      if (StartOfLine) and (BlankLine) and (C > ' ') then
        Break;
    end;

    if (C > ' ') then
      StartOfLine := False;

    Inc(I);
  end;
  HasBlankLines := False;
  HandleItem(I);

  if (Items <> '') then
  begin
    List := '@unorderedList(' + sLineBreak;
    if (Compact) then
      List := List + '@itemSpacing(Compact)' + sLineBreak;
    List := List + Items + ')' + sLineBreak;

    S := S.Remove(Index, I - Index);
    S := S.Insert(Index, List);
  end;
end;

function PreprocessComment(const Comment: String): String;
var
  I, NewI, WordStart, WordEnd: Integer;
  C: Char;
  StartOfLine: Boolean;
begin
  Result := Comment;
  I := 0;
  StartOfLine := True;
  WordStart := -1;

  while (I < Result.Length) do
  begin
    C := Result.Chars[I];
    case C of
      #10:
        begin
          StartOfLine := True;
          WordStart := -1;
        end;

      '<':
        begin
          HandleHtmlTag(Result, I);
          WordStart := -1;
        end;

      'A'..'Z', 'a'..'z':
        if (StartOfLine) and (WordStart < 0) then
          WordStart := I;

      ':':
        if (WordStart >= 0) then
        begin
          { Section must be on a single line }
          WordEnd := I;
          if (not LineContainsText(Result, I + 1, NewI)) then
          begin
            I := NewI;
            HandleSection(Result, WordStart, WordEnd, I);
            I := WordStart + 1;
            WordStart := -1;
          end;
        end;

      '*':
        if StartOfLine then
        begin
          HandleUnorderedList(Result, I);
          WordStart := -1;
        end;
    else
      WordStart := -1;
    end;

    if (C > ' ') then
      StartOfLine := False;

    Inc(I);
  end;
end;

end.
