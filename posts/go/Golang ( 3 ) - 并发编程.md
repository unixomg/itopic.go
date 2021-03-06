```
{
    "url": "goroutine",
    "time": "2020/04/20 11:00",
    "tag": "Golang",
    "toc": "yes"
}
```

# 一、Go协程

只需要在方法前加一个`go`关键字就可以让一个普通方法协程化。以下面的代码为例，一般同步阻塞的编码方式下会按顺序打印012然后再输出Finish. 示例中启动了3个协程之后主进程会继续往下执行，不会等待函数返回，大概率会先看到Finish输出，然后看到012或者210。

即加上`go`关键字之后程序不会同步阻塞主进程，协程的执行速度跟程序复杂性关系，无法保证先启动的协程先执行完毕。

```
func main() {
	for i := 0; i < 3; i++ {
		go func(v int) {
			fmt.Println(v)
		}(i)
	}
	fmt.Println("Finish.")
	time.Sleep(time.Second)
}
```

通常情况下同步的逻辑方式书写是最方便的，无须考虑程序逻辑的先后关系，上面示例最后一行休眠1秒，确保协程可以执行完毕，但正常逻辑下无法确保1秒内协程能执行完毕，也不会只执行一个打印这么简单，通常还需要能获取到函数的返回。所以需要有一种通信方式能解决此类问题，而通道正是为协程间通信而产生。

# 二、 通道

通道（channel）提供了协程之间的`通信方式`以及`运行同步机制`。

## 2.1 通道定义

Channel是Go中的一个核心类型，你可以把它看成一个管道，通过它并发核心单元就可以发送或者接收数据进行通讯，它的操作符是箭头 `<-`(箭头的指向就是数据的流向)。

```
ch <- v    // 发送值v到Channel ch中
v := <-ch  // 从Channel ch中接收数据，并将数据赋值给v
```

就像`map`和`slice`数据类型一样,`channel`必须先创建再使用:

```
ch := make(chan int)
```

## 2.2 select语句

select 是`Go`中的一个控制结构，类似于用于通信的`switch`语句。每个`case`必须是一个通信操作，要么是发送要么是接收。`select`随机执行一个可运行的`case`。如果没有`case`可运行，它将阻塞，直到有 `case`可运行。一个默认的子句应该总是可运行的。

**基本用法**

```
select {
case <- chan1:
// 如果chan1成功读到数据，则进行该case处理语句
case chan2 <- 1:
// 如果成功向chan2写入数据，则进行该case处理语句
default:
// 如果上面都没有成功，则进入default处理流程
}
```
以下描述了 select 语句的语法：

- 每个`case`都必须是一个通信
- 所有`channel`表达式都会被求值
- 所有被发送的表达式都会被求值
- 如果任意某个通信可以进行，它就执行，其他被忽略。
- 如果有多个`case`都可以运行，`Select`会随机公平地选出一个执行。其他不会执行。
- 否则：
	- 如果有`default`子句，则执行该语句。
	- 如果没有`default`子句，`select`将阻塞，直到某个通信可以运行；`Go`不会重新对`channel`或值进行求值。

**示例**

```
func main() {
	ch1 := make(chan int)
	ch2 := make(chan string)

	go func() {
		time.Sleep(1 * time.Second)
		ch1 <- 1
	}()

	go func() {
		time.Sleep(2 * time.Second)
		ch2 <- "Hello"
	}()

	fmt.Println("Start")
	select {
	case <-ch1:
		fmt.Println("Read From ch1")
	case <-ch2:
		fmt.Println("Read From ch2")
	default:
		fmt.Println("Read From Default")
	}
	fmt.Println("END")
}
```

- 因为两个通道都要等1秒，存在default则直接执行了default语句，打印`Read From Default`，退出`swith`
- 如果去掉default，则阻塞等待打印出`Read From ch1`

如果`select`里啥都没有 `select{}`，则会等待，达到阻塞的目的。


# 三、协程同步

## 3.1 通过Channel同步

创建了一个存储10个bool类型的通道，函数执行成功向通道里写入true，执行失败向通道里写入false。启动一个循环从通道读取数据，读取10次之后程序在打印最后的结果：

`true true true true false true false false false false [0 1 2 3 4]`

```
func main() {
	ch := make(chan bool, 10)

	data := make([]int, 5)
	for i := 0; i < 10; i++ {
		go func(idx int) {
			defer func() {
				if err := recover(); err != nil {
					ch <- false
				}
			}()
			data[idx] = idx
			ch <- true
		}(i)
	}
	for j := 0; j < 10; j++ {
		fmt.Print(<-ch, " ")
	}
	fmt.Println(data)
}
```


## 3.2 通过sync.WaitGroup同步

控制流程同步等待也可以通过`sync.WaitGroup`来实现，`WaitGroup`对象内部有一个计数器，最初从0开始，它有三个方法：

- `Add()`: 计数器增加N
- `Done()`: 完成一个任务，计数器减少1
- `Wait()`: 同步阻塞，计数器为0之后才继续向下执行

```
func main() {
	var wg sync.WaitGroup

	data := make([]int, 5)
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func(idx int) {
			defer func() {
				if err := recover(); err != nil {
					fmt.Println(err)
				}
				wg.Done()
			}()
			data[idx] = idx
		}(i)
	}
	wg.Wait()
	fmt.Println(data)
}
```

## 3.3 模拟生产者与消费者

```
func main() {
	ch := make(chan string)

	ticker := time.NewTicker(time.Second)
	go func() {
		for {
			<-ticker.C
			ch <- time.Now().Format("2006-01-02 15:04:05")
		}
	}()

	go func() {
		for {
			fmt.Println(<-ch)
		}
	}()

	select {}
}
```

这个示例启动了2个协程，一个用来每一秒往通道里写一个时间，另一个用来从通道里读取，模拟生产者和消费者的情况。当然就示例本身实现起来只需要上面生产者并打印即可。

```
func main() {
	ticker := time.NewTicker(time.Second)
	for {
		select {
		case <-ticker.C:
			fmt.Println(time.Now().Format("2006-01-02 15:04:05"))
		}
	}
}
```

## 3.4 读取Channel超时

通过`select + time.After`实现超时控制。

```
func main() {
	ch := make(chan bool)
	go func() {
		time.Sleep(3 * time.Second)
		ch <- true
	}()

	select {
	case <-ch:
		fmt.Println("Read From CH")
	case <-time.After(time.Second):
		fmt.Println("timeout")
	}
}
```

本章节主要通过`channel`来控制流程在该同步等待地方可以同步等待，对数据的交互主要在下一章节讨论。

# 四、协程通信

协程之间数据交互上主要有两种方式，一种为全局变量然后通过锁来控制原子性，另一种则是通过channel来进行通信。

## 4.1 全局变量

启动10个协程来执行1加到10的操作，s变量为协程共享，所以需要加锁才会正确输出55，若去掉锁的三行代码，则会出现非55的情况。

```
func sum() int {
	s := 0
	var wg sync.WaitGroup
	var mutex sync.Mutex
	wg.Add(10)
	for i := 1; i <= 10; i++ {
		go func(i int) {
			mutex.Lock()
			s += i
			mutex.Unlock()
			wg.Done()
		}(i)
	}
	wg.Wait()
	return s
}
func main() {
	for i := 0; i < 100; i++ {
		fmt.Print(sum(), " ")
	}
}
```

## 4.2 通过Channel来通信

将结果写到通道中，从通道中读取结果进行累加。

```
func sum() int {
	ch := make(chan int)
	for i := 1; i <= 10; i++ {
		go func(i int) {
			ch <- i
		}(i)
	}
	s := 0
	for i := 0; i < 10; i++ {
		s += <-ch
	}
	return s
}
func main() {
	for i := 0; i < 100; i++ {
		fmt.Print(sum(), " ")
	}
}
```

---

- [1] [go 语言之行--golang 核武器 goroutine 调度原理、channel 详解](https://learnku.com/articles/41668)
- [2] [一文读懂什么是进程、线程、协程](https://www.jianshu.com/p/80bde972196d)
- [3] [七周七并发模型](http://yuedu.163.com/source/a4b77ff9abaf4109acd11c38e5c8babc_4)
- [4] [Go语言通道（chan）——goroutine之间通信的管道](http://c.biancheng.net/view/97.html)
- [5] [golang sync包互斥锁和读写锁的使用](http://www.361way.com/rwmutex/5984.html)