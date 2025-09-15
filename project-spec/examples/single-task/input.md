# Issue #42: Code Review Request

@gitaiteams

Please review this Python function and suggest improvements:

```python
def calculate_average(numbers):
    total = 0
    count = 0
    for n in numbers:
        total = total + n
        count = count + 1
    return total / count
```

Focus on error handling and pythonic style.