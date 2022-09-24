package verifier

import (
	"fmt"
	"regexp"
	"strconv"
	"strings"
)

var (
	outerMatch = regexp.MustCompile(`^\[debug\] \(&\) \[(.*)\]$`)
	innerMatch = regexp.MustCompile(`{ ([^{]+) }`)
)

func ParseEntry(text string) (*Entry, error) {
	trimmed := strings.Split(strings.Trim(text, " {}"), ", ")
	if len(trimmed) < 5 {
		return nil, fmt.Errorf("%s is missing data", text)
	}

	r := &Entry{}

	key, err := strconv.ParseUint(trimmed[0], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse key %s: %w", trimmed[0], err)
	}
	r.Key = key

	value, err := strconv.ParseUint(trimmed[1], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse value %s: %w", trimmed[1], err)
	}
	r.Value = value

	parent, err := strconv.ParseUint(trimmed[2], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse parent %s: %w", trimmed[2], err)
	}
	r.Parent = parent

	left, err := strconv.ParseUint(trimmed[3], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse left child %s: %w", trimmed[3], err)
	}
	r.LeftChild = left

	right, err := strconv.ParseUint(trimmed[4], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("failed to parse right child %s: %w", trimmed[4], err)
	}
	r.RightChild = right

	if len(trimmed) > 5 {
		meta, err := strconv.ParseUint(trimmed[5], 10, 64)
		if err != nil {
			return nil, fmt.Errorf("failed to parse metadata %s: %w", trimmed[5], err)
		}

		r.Metadata = uint8(meta)
	}

	return r, nil
}

func ParseMoveTestOut(text string) ([][]Entry, error) {
	lines := strings.Split(text, "\n")
	var result [][]Entry
	for _, aLine := range lines {
		matchedStrings := outerMatch.FindStringSubmatch(aLine)
		if len(matchedStrings) == 0 {
			fmt.Printf("failed to find outer match: %s\n", aLine)
			continue
		}
		if len(matchedStrings) != 2 {
			fmt.Printf("failed to find group in: %s\n", aLine)
		}

		entryTexts := innerMatch.FindAllStringSubmatch(matchedStrings[1], -1)

		if len(entryTexts) == 0 {
			fmt.Printf("no match for %s\n", matchedStrings[1])
			continue
		}

		var thisLine []Entry

		for _, anEntry := range entryTexts {
			e, err := ParseEntry(anEntry[1])
			if err != nil {
				return nil, err
			}
			thisLine = append(thisLine, *e)
		}
		result = append(result, thisLine)
	}

	if len(result) == 0 {
		return nil, fmt.Errorf("cannot find any match in:\n%s", text)
	}

	return result, nil
}
